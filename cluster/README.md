# ECS Autoscaling cluster

This module creates an autoscaling cluster for ECS.

# Usage Example

For ecs_lambda doc see [here](../lambda_ecs_draining/README.md)

```
resource "aws_ecs_cluster" "cluster" {
  name = "cluster"
}

module "ecs_lambda" {
  source = "github.com/MakeMeReach/terraform-aws-ecs//lambda_ecs_draining"

  name = "lambda"
}

module "cluster" {
  source = "github.com/MakeMeReach/terraform-aws-ecs//cluster"

  name = "cluster"

  ecs_cluster_id = "${aws_ecs_cluster.cluster.id}"

  vpc_id = <The VPC ID where the cluster should be launched>
  subnet_ids = <The Subnets IDs where the cluster should be launched>

  instance_security_groups_ids = [<A list of security_groups ids to apply to all instances of your cluster>]
  instance_ami = <The AMI use for the cluster (if non provided we will use the one announced by SSM for your region)>
  instance_type = <The type of instance to use for your cluster>
  instance_count = <The number of instance your cluster should contain>
  instance_iam_profile = <An IAM profile to apply to your instances>
  instance_custom_userdata = <A sh script to append at the end of the already defined user_data>

  tags_as_map = {
    Hello = "World"
  }

  has_topic_arn = true
  sns_topic_arn = "${module.ecs_lambda.sns_topic_arn}"
}
```
