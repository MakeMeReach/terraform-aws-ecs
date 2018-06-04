# AWS ECS Cloudwatch Scheduled Task Terraform Module

A Terraform module to schedule task using cloudwatch.
The module [scheduled_task](./scheduled_task/main.tf) provision an individual
task:
  * Creates a IAM role for cloudwatch to run a task
    ([See](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/CWE_IAM_role.html))
  * Creates a Cloudwatch event with a cron-style or rate expression that will
    run the task with any `overrides` you provide.

Allows scheduling standalone AWS EC2 Container Service (ECS) tasks with
Terraform. There are two modules:

This project is inspired by
[this module](https://github.com/jbrook/ecs-task-scheduler-tf) but remove the
lambda.

## Usage Example

Simple usage:
```
/**
 * Periodically runs a job
 */
module "schedule_task_1" {
  source = "github.com/MakeMeReach/terraform-aws-ecs//scheduled_task"

  name = "task_1"
  ecs_cluster_arn = "<ecs cluster arn>"
  ecs_task_definition_arn = "<task definition arn>"

  cloudwatch_schedule_expression = "cron(50 8 ? * * *)"

  # Optionals
  ecs_task_container_overrides = {
    name = "container_1"
    command = ["echo", "'Hello World!'"]
    environment = [
      {
        name = "MY_ENV_VAR"
        value = "Hello"
      }
    ]
  }
  ecs_task_count = 2
}
```

## IAM

If you do not provide the `cloudwatch_event_iam_role_arn` variable, the module
will create a new role with the correct policy to run you task.

The IAM role is specific to a task and not to a cloudwatch event so it might be
interesting to not re-create one per scheduled tasks.

### Chaining IAM role between modules

It will work but be aware that deleting the first module will be painful
because other modules needs the IAM role to work properly.

This is the best solution if you only schedule a task once.

```
/**
 * Avoid creating multiple IAM role for the same task by using the role created
 * in the first scheduled_task
 */
module "schedule_task_1" {
  source = "github.com/MakeMeReach/terraform-aws-ecs//scheduled_task"

  name = "task_1"
  ecs_cluster_arn = "<ecs cluster arn>"
  ecs_task_definition_arn = "<task definition arn>"

  cloudwatch_schedule_expression = "cron(50 8 ? * * *)"

  # Optionals
  ecs_task_container_overrides = {
    name = "container_1"
    command = ["echo", "'Hello World!'"]
    environment = [
      {
        name = "MY_ENV_VAR"
        value = "Hello"
      }
    ]
  }
  ecs_task_count = 2
}

module "schedule_task_2" {
  source = "github.com/MakeMeReach/terraform-aws-ecs//scheduled_task"

  name = "task_2"
  ecs_cluster_arn = "<ecs cluster arn>"
  ecs_task_definition_arn = "<task definition arn>"

  cloudwatch_schedule_expression = "cron(50 8 ? * * *)"

  # Optionals
  ecs_task_container_overrides = {
    name = "container_1"
    command = ["echo", "'Hello World!'"]
    environment = [
      {
        name = "MY_ENV_VAR"
        value = "Hello"
      }
    ]
  }
  ecs_task_count = 2
  cloudwatch_event_iam_role_arn = "${module.schedule_task_1.cloudwatch_event_iam_role_arn}"
}
```

### Create IAM role outside and pass it to scheduled tasks

This way you will have no problem to delete any scheduled task you create.

This is the best option if you define multiple schedule for the same task.

```
resource "aws_iam_role" "cloudwatch_event_role" {
  name_prefix = "cloudwatch_event"
  assume_role_policy = <<DOC
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "events.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
DOC
}

resource "aws_iam_role_policy" "cloudwatch_event_run_task_with_any_role" {
  name_prefix = "cloudwatch_event_run_task_with_any_role"
  role = "${aws_iam_role.cloudwatch_event_role.id}"
  policy = <<DOC
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "iam:PassRole",
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": "ecs:RunTask",
            "Resource": "${replace(<task definition arn>, "/:\\d+$/", ":*")}"
        }
    ]
}
DOC
}

/**
 * Create a single IAM role for the task and pass it along to all scheduled tasks
 */
module "schedule_task_1" {
  source = "github.com/MakeMeReach/terraform-aws-ecs//scheduled_task"

  name = "task_1"
  ecs_cluster_arn = "<ecs cluster arn>"
  ecs_task_definition_arn = "<task definition arn>"

  cloudwatch_schedule_expression = "cron(50 8 ? * * *)"

  # Optionals
  ecs_task_container_overrides = {
    name = "container_1"
    command = ["echo", "'Hello World!'"]
    environment = [
      {
        name = "MY_ENV_VAR"
        value = "Hello"
      }
    ]
  }
  ecs_task_count = 2
  cloudwatch_event_iam_role_arn = "${aws_iam_role.cloudwatch_event_role.arn}"
}

module "schedule_task_2" {
  source = "github.com/MakeMeReach/terraform-aws-ecs//scheduled_task"

  name = "task_2"
  ecs_cluster_arn = "<ecs cluster arn>"
  ecs_task_definition_arn = "<task definition arn>"

  cloudwatch_schedule_expression = "cron(50 8 ? * * *)"

  # Optionals
  ecs_task_container_overrides = {
    name = "container_1"
    command = ["echo", "'Hello World!'"]
    environment = [
      {
        name = "MY_ENV_VAR"
        value = "Hello"
      }
    ]
  }
  ecs_task_count = 2
  cloudwatch_event_iam_role_arn = "${aws_iam_role.cloudwatch_event_role.arn}"
}
```
