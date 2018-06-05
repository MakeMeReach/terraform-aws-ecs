# A collection of Terraform Module to work with AWS ECS

This repository contains multiple modules to manage or facilitate work with ECS.

Included modules:
 - [cluster](./cluster/README.md): create an autoscaling group for your ECS
 cluster.
 - [lambda_ecs_draining](./lambda_ecs_draining/README.md): create a lambda to
 correctly handle scale-down events of an autoscaling group of ECS.
 - [scheduled_task](./scheduled_task/README.md): create a CloudWatch event that
 will run a task periodically (cron-style or rate expression)
 - [service](./service/README.md): create a task and its service
 (with possibility to add the service to an Application Load Balancer).
