variable "name" {
  description = "(required) The name used for the cluster and other related resources"
}

variable "ecs_cluster_id" {
  description = "(required) The ECS cluster id"
}

variable "vpc_id" {
  description = "(required) The VPC to create EC2 instance in"
}

variable "subnet_ids" {
  type        = "list"
  description = "(required) The different subnets to launch the EC2 in"
}

variable "instance_security_groups_ids" {
  type        = "list"
  description = "(optional) A list of security group to apply to all EC2 instances of the cluster"
  default     = []
}

variable "instance_ami" {
  default     = ""
  description = "(optional) The AMI to use for the EC2 instances of the cluster. If not provided we will use the one announced by aws ssm (https://docs.aws.amazon.com/AmazonECS/latest/developerguide/launch_container_instance.html)"
}

variable "instance_type" {
  description = "(required) The type of EC2 instance the cluster should be comprised of"
}

variable "instance_count" {
  description = "(required) The number of EC2 instance to start for this cluster"
}

variable "instance_iam_profile" {
  default     = ""
  description = "(optional) The profile for the EC2 instance of the cluster"
}

variable "instance_custom_userdata" {
  default     = ""
  description = "(optional) A script that will get appended to the userdata"
}

variable "tags_as_map" {
  default     = {}
  description = "(optional) A map of tags to apply to created resources"
}

variable "has_topic_arn" {
  description = "(optional) Do you provide an ARN. (required if `sns_topic_arn` is set)"
  default = false
}
variable "sns_topic_arn" {
  default     = ""
  description = "(optional) An ARN to notify when the ASG in scaling in (see the ecs_lambda module for an explanation)"
}

locals {
  tags_asg_format = ["${null_resource.tags_as_list_of_maps.*.triggers}"]
}

resource "null_resource" "tags_as_list_of_maps" {
  count = "${length(keys(var.tags_as_map))}"

  triggers = "${map(
    "key", "${element(keys(var.tags_as_map), count.index)}",
    "value", "${element(values(var.tags_as_map), count.index)}",
    "propagate_at_launch", "true"
  )}"
}

data "aws_ssm_parameter" "foo" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux/recommended"
}

data "template_file" "user_data" {
  template = "${file("${path.module}/files/user_data.sh.tpl")}"

  vars {
    cluster_name    = "${var.ecs_cluster_id}"
    custom_userdata = "${var.instance_custom_userdata}"
  }
}

resource "aws_launch_configuration" "autoscaling_cluster" {
  name_prefix = "${var.name}"
  image_id             = "${var.instance_ami == "" ? replace(data.aws_ssm_parameter.foo.value, "/.*\"image_id\":\"(ami-[a-zA-Z0-9]+)\",\".*/", "$1") : var.instance_ami}"
  instance_type        = "${var.instance_type}"

  security_groups      = ["${var.instance_security_groups_ids}"]
  iam_instance_profile = "${var.instance_iam_profile}"

  user_data            = "${data.template_file.user_data.rendered}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "autoscaling_cluster" {
  name                = "${aws_launch_configuration.autoscaling_cluster.name}"
  launch_configuration = "${aws_launch_configuration.autoscaling_cluster.name}"
  vpc_zone_identifier = ["${var.subnet_ids}"]
  health_check_type   = "EC2"
  min_size            = "${var.instance_count}"
  max_size            = "${var.instance_count}"
  desired_capacity    = "${var.instance_count}"

  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupStandbyInstances",
    "GroupTerminatingInstances",
    "GroupTotalInstances",
  ]

  tags = ["${concat(
    list(map("key", "Name", "value", var.name, "propagate_at_launch", true)),
    local.tags_asg_format
  )}"]

  lifecycle {
    create_before_destroy = true
  }

  timeouts {
    delete = "1h"
  }
}

resource "aws_iam_role" "iam_role_for_asg_lifecycle" {
  count = "${var.has_topic_arn}"
  name_prefix  = "iam_role_for_asg_lifecycle"

  description = "Autoscaling role for lifecycle (ecs cluster)"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "autoscaling.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "iam_role_for_asg_lifecycle" {
  count      = "${var.has_topic_arn}"
  role       = "${aws_iam_role.iam_role_for_asg_lifecycle.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AutoScalingNotificationAccessRole"
}

resource "aws_autoscaling_lifecycle_hook" "asg_cluster_lifecycle_scale_in" {
  count = "${var.has_topic_arn}"

  name                   = "lifecycle_handle_ecs_cluster_downscale"
  autoscaling_group_name = "${aws_autoscaling_group.autoscaling_cluster.name}"
  default_result         = "CONTINUE"
  heartbeat_timeout      = 900
  lifecycle_transition   = "autoscaling:EC2_INSTANCE_TERMINATING"

  notification_target_arn = "${var.sns_topic_arn}"
  role_arn                = "${aws_iam_role.iam_role_for_asg_lifecycle.arn}"
}
