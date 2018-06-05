# ECS Lambda container draining

When running ECS agent on EC2 inside an autoscaling group, ECS does not
automatically detect and handle scale-down events.

This module creates the lambda and an SNS topic that you can plug as a lifecycle
hook of your autoscaling group (on `autoscaling:EC2_INSTANCE_TERMINATING`) to
set the instance as `DRAINING` (thus preventing new task from being run on this
instance and moving tasks to non-draining hosts).

This module is intended to be used with the [cluster module](../cluster/README.md)
but can be directly used with an existing autoscaling group.

This project is inspired by
[this repo](https://github.com/aws-samples/ecs-cid-sample) but implements it in
Terraform.

# Usage Example

```
module "ecs_lambda" {
  source = "github.com/MakeMeReach/terraform-aws-ecs//lambda_ecs_draining"

  name = "lambda"
  tags_as_map = {
    Hello = "World"
    This = "is_a_tag"
  }
}
```
