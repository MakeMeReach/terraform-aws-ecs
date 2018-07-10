variable "name" {
  description = "(required) Name for this scheduled task. It will be prepend to all name of resources of this module."
}

variable "ecs_cluster_arn" {
  description = "(required) The ARN for the ecs cluster."
}

variable "ecs_task_definition_arn" {
  default = "(required) The ARN of the definition for the task."
}

variable "ecs_task_container_overrides" {
  type        = "map"
  default     = {}
  description = "(optional) The overrides section that will get passed to the task. See (https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_ContainerOverride.html)."
}

variable "ecs_task_count" {
  default     = "1"
  description = "(optional) The number of task that cloudwatch should start."
}

variable "cloudwatch_event_iam_role_arn" {
  description = <<EOF
(optional) The role used by cloudwatch to run the task. If not provided, we will create one (and it will be available as the `cloudwatch_event_iam_role_arn` output value).
The role should allow `iam:PassRole` and `ecs:RunTask`.
EOF
}

variable "cloudwatch_schedule_expression" {
  description = "(required) The expression used for the cloudwatch event rule."
}

resource "aws_cloudwatch_event_rule" "ecs_scheduled_rule" {
  name                = "${var.name}"
  schedule_expression = "${var.cloudwatch_schedule_expression}"
}

resource "aws_cloudwatch_event_target" "ecs_scheduled_task" {
  arn      = "${var.ecs_cluster_arn}"
  rule     = "${aws_cloudwatch_event_rule.ecs_scheduled_rule.name}"
  role_arn = "${var.cloudwatch_event_iam_role_arn}"

  ecs_target = {
    task_count          = "${var.ecs_task_count}"
    task_definition_arn = "${var.ecs_task_definition_arn}"
  }

  input = <<DOC
{
  "containerOverrides": [
    ${jsonencode(var.ecs_task_container_overrides)}
  ]
}
DOC
}

output "cloudwatch_event_rule_arn" {
  value = "${aws_cloudwatch_event_rule.ecs_scheduled_rule.arn}"
}
