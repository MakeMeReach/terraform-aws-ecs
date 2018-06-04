# AWS ECS Task and service Terraform Module

A Terraform module that create a task and its linked service.
The module [service](./service/main.tf) provision:
  * Create a task as defined by the user.
  * Create a service for this task and if provided, link it to a load balancer.

## Usage Example

Service without load balancer:
```
module "worker" {
  source = "github.com/MakeMeReach/terraform-aws-ecs//service"

  name = "worker"
  ecs_cluster_id = "<ECS cluster ARN the task and service will run on>"
  ecs_task_docker_image = "<docker image>"
  ecs_task_memory_reservation = "512"
  ecs_task_memory = "1024"
  ecs_task_memory = "1024"
  ecs_task_additional_parameters = <<EOF
"environment": [
  {
    "name": "ENV",
    "value": "dev"
  }
],
"dockerLabels": {
  "hello": "world"
}
EOF
  ecs_service_desired_count = "1"
}
```

Example with load balancer target group:
```
resource "aws_iam_role" "ecs_service_role" {
  name = "ecs_service_role"

  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ecs.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "ecs_service_policy" {
  name = "ecs_service_policy"
  role = "${aws_iam_role.ecs_service_role.id}"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:AttachNetworkInterface",
                "ec2:CreateNetworkInterface",
                "ec2:CreateNetworkInterfacePermission",
                "ec2:DeleteNetworkInterface",
                "ec2:DeleteNetworkInterfacePermission",
                "ec2:Describe*",
                "ec2:DetachNetworkInterface",
                "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
                "elasticloadbalancing:DeregisterTargets",
                "elasticloadbalancing:Describe*",
                "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
                "elasticloadbalancing:RegisterTargets",
                "route53:ChangeResourceRecordSets",
                "route53:CreateHealthCheck",
                "route53:DeleteHealthCheck",
                "route53:Get*",
                "route53:List*",
                "route53:UpdateHealthCheck",
                "servicediscovery:DeregisterInstance",
                "servicediscovery:Get*",
                "servicediscovery:List*",
                "servicediscovery:RegisterInstance",
                "servicediscovery:UpdateInstanceCustomHealthStatus"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

module "api" {
  source = "github.com/MakeMeReach/terraform-aws-ecs//service"

  name = "api"
  ecs_cluster_id = "<ECS cluster ARN the task and service will run on>"

  ecs_task_docker_image = "<docker image>"
  ecs_task_memory_reservation = "512"
  ecs_task_memory = "1024"
  ecs_task_docker_port = "<The port your docker exposes>"
  ecs_task_additional_parameters = <<EOF
"environment": [
  {
    "name": "ENV",
    "value": "dev"
  }
],
"dockerLabels": {
  "hello": "world"
}
EOF
  ecs_service_desired_count = 1
  ecs_service_role_arn = "${aws_iam_role.ecs_service_role.arn}"
  alb_target_group_arn = "<ARN of the target group your docker should register to>"
}
```
