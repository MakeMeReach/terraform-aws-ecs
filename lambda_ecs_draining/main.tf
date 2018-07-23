variable "name" {
  description = "(Required) The name used for the lambda and other related resources"
}

variable "tags_as_map" {
  default     = {}
  description = "(optional) A map of tags to apply to created resources."
}

resource "aws_iam_role" "iam_role_for_ecs_cluster_lambda" {
  name_prefix = "iam_for_ecs_cluster_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "iam_policy_for_ecs_cluster_lambda" {
  name_prefix = "iam_policy_for_ecs_cluster_lambda"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Resource": "*",
            "Action": [
              "autoscaling:CompleteLifecycleAction",
              "logs:CreateLogGroup",
              "logs:CreateLogStream",
              "logs:PutLogEvents",
              "ec2:DescribeInstances",
              "ec2:DescribeInstanceAttribute",
              "ec2:DescribeInstanceStatus",
              "ec2:DescribeHosts",
              "ecs:ListContainerInstances",
              "ecs:SubmitContainerStateChange",
              "ecs:SubmitTaskStateChange",
              "ecs:DescribeContainerInstances",
              "ecs:UpdateContainerInstancesState",
              "ecs:ListTasks",
              "ecs:DescribeTasks",
              "sns:Publish",
              "sns:ListSubscriptions"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "iam_ecs_cluster_lambda_main_policy" {
  role       = "${aws_iam_role.iam_role_for_ecs_cluster_lambda.name}"
  policy_arn = "${aws_iam_policy.iam_policy_for_ecs_cluster_lambda.arn}"
}

resource "aws_iam_role_policy_attachment" "iam_ecs_cluster_lambda_asg_notif_policy" {
  role       = "${aws_iam_role.iam_role_for_ecs_cluster_lambda.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AutoScalingNotificationAccessRole"
}

data "archive_file" "lambda_code_zipped" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/source/"
  output_path = "${path.module}/lambda/lambda.zip"
}

resource "aws_lambda_function" "lambda_handle_ecs_cluster_downscale" {
  filename         = "${path.module}/lambda/lambda.zip"
  source_code_hash = "${data.archive_file.lambda_code_zipped.output_base64sha256}"

  function_name = "${var.name}-ecs-downscaler"
  role          = "${aws_iam_role.iam_role_for_ecs_cluster_lambda.arn}"

  handler = "index.lambda_handler"
  runtime = "python2.7"
  timeout = 300

  tags = "${merge(map("Name", "lambda_handle_ecs_cluster_downscale"), var.tags_as_map)}"

  ignore_changes = ["last_modified", "filename"]
}

resource "aws_sns_topic" "sns_ecs_cluster_lifecycle" {
  name = "${var.name}-sns-ecs-cluster-lifecycle"
}

resource "aws_lambda_permission" "allow_sns" {
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.lambda_handle_ecs_cluster_downscale.function_name}"
  principal     = "sns.amazonaws.com"
  source_arn    = "${aws_sns_topic.sns_ecs_cluster_lifecycle.arn}"
}

resource "aws_sns_topic_subscription" "sns_ecs_cluster_lifecycle" {
  topic_arn = "${aws_sns_topic.sns_ecs_cluster_lifecycle.arn}"
  protocol  = "lambda"
  endpoint  = "${aws_lambda_function.lambda_handle_ecs_cluster_downscale.arn}"
}

output "lambda_arn" {
  value = "${aws_lambda_function.lambda_handle_ecs_cluster_downscale.arn}"
}

output "sns_topic_arn" {
  value = "${aws_sns_topic.sns_ecs_cluster_lifecycle.arn}"
}
