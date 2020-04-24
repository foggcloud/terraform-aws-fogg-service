locals {
  name = var.name
}

resource "aws_ecs_task_definition" "this" {
  family       = local.name
  network_mode = "bridge"

  task_role_arn      = aws_iam_role.task.arn
  execution_role_arn = aws_iam_role.execution.arn

  requires_compatibilities = ["EC2"]

  tags = {
    Managed : "Terraform"
  }

  cpu    = 128
  memory = 64

  volume {
    name = "common"

    docker_volume_configuration {
      scope  = "task"
      driver = "local"
      driver_opts = {
        type : "tmpfs"
        device : "tmpfs"
        o : "size=10m,uid=1000"
      }
    }
  }

  volume {
    name = "data"

    efs_volume_configuration {
      file_system_id = var.efs_id
      root_directory = "/"
    }
  }

  container_definitions = jsonencode(
    [
      {
        name         = "home",
        image        = var.image
        privileged   = false,
        environment  = [],
        entryPoint   = var.entrypoint
        essential    = true,
        portMappings = [],
        volumesFrom  = [],
        cpu          = 0,
        mountPoints = [
          {
            sourceVolume  = "common",
            containerPath = "/common"
          },
          {
            sourceVolume  = "data",
            containerPath = "/data"
          }
        ]
      }
    ]
  )
}

resource "aws_ecs_service" "this" {
  name            = local.name
  cluster         = var.cluster
  task_definition = aws_ecs_task_definition.this.arn

  scheduling_strategy                = "REPLICA"
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 0
  desired_count                      = 1
}

resource "aws_iam_role" "execution" {
  name               = format("%s-%s-%s", local.name, "execution", terraform.workspace)
  assume_role_policy = data.aws_iam_policy_document.execution_assume.json
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "execution_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "task" {
  name               = format("%s-%s-%s", local.name, "task", terraform.workspace)
  assume_role_policy = data.aws_iam_policy_document.task_assume.json
}

data "aws_iam_policy_document" "task_assume" {
  statement {
    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}
