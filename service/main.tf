variable "name" {
  description = "(required) The name for you task and service."
}

variable "ecs_cluster_id" {
  description = "(required) The cluster used to run this service."
}

variable "ecs_task_docker_image" {
  description = "(required) The docker image used to run."
}

variable "ecs_task_memory_reservation" {
  description = "(required) The amount of memory reserved for this task."
}

variable "ecs_task_memory" {
  description = "(required) The maximum amount of memory for this task."
}

variable "ecs_task_docker_port" {
  default     = ""
  description = "(optional) The port exposed by this docker. Only required if used with a load balancer."
}

variable "ecs_task_additional_parameters" {
  default     = ""
  description = "(optional) Any additional parameters to define the task. This sould consist of key/values pair that you want to apply to the `container_definitions` of the task"
}

variable "ecs_service_desired_count" {
  description = "(optional) How many task should this service run."
  default     = 1
}

variable "ecs_service_role_arn" {
  description = "(optional) Only used if a load balancer needs to be attached to your service."
  default     = ""
}

variable "alb_target_group_arn" {
  description = "(optional) The target group to attach to the service."
  default     = ""
}

locals {
  load_balancer_config {
    enabled = {
      target_group_arn = "${var.alb_target_group_arn}"
      container_name   = "${var.name}"
      container_port   = "${var.ecs_task_docker_port}"
    }

    disabled = []
  }

  port_mappings = <<EOF
"portMappings": [
  {
    "containerPort": ${var.ecs_task_docker_port}
  }
]
EOF
}

resource "aws_ecs_task_definition" "task" {
  family = "${var.name}"

  container_definitions = <<EOF
[
  {
    "name": "${var.name}",
    "image": "${var.ecs_task_docker_image}",
    "memoryReservation": ${var.ecs_task_memory_reservation},
    "memory": ${var.ecs_task_memory}
    ${var.ecs_task_docker_port == "" ? "" : ",${local.port_mappings}"}
    ${var.ecs_task_additional_parameters == "" ? "" : ",${var.ecs_task_additional_parameters}"}
  }
]
EOF
}

resource "aws_ecs_service" "service" {
  count = "${var.alb_target_group_arn == "" ? 1 : 0}"

  name            = "${var.name}"
  cluster         = "${var.ecs_cluster_id}"
  task_definition = "${aws_ecs_task_definition.task.arn}"
  desired_count   = "${var.ecs_service_desired_count}"

  lifecycle {
    ignore_changes = ["desired_count"]
  }
}

resource "aws_ecs_service" "service_with_target_group" {
  count = "${var.alb_target_group_arn == "" ? 0 : 1}"

  name            = "${var.name}"
  cluster         = "${var.ecs_cluster_id}"
  task_definition = "${aws_ecs_task_definition.task.arn}"
  desired_count   = "${var.ecs_service_desired_count}"
  iam_role        = "${var.ecs_service_role_arn}"

  load_balancer = {
    target_group_arn = "${var.alb_target_group_arn}"
    container_name   = "${var.name}"
    container_port   = "${var.ecs_task_docker_port}"
  }

  lifecycle {
    ignore_changes = ["desired_count"]
  }
}