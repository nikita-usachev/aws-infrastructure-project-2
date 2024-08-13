# data

data "aws_vpc" "selected" {
  id      = var.vpc_id
  default = var.vpc_id != null ? false : true
}

# iam

data "aws_iam_policy_document" "service_assume_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "service_role" {
  name               = "${local.common_tags.Name}-service-role"
  assume_role_policy = data.aws_iam_policy_document.service_assume_policy.json
  tags               = merge(local.tags, { Name = "${local.common_tags.Name}-service-role" })
}

resource "aws_iam_role_policy_attachment" "service_policy" {
  role       = aws_iam_role.service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
}

data "aws_iam_policy_document" "task_assume_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "task_role" {
  name               = "${local.common_tags.Name}-task-role"
  assume_role_policy = data.aws_iam_policy_document.task_assume_policy.json
  tags               = merge(local.tags, { Name = "${local.common_tags.Name}-task-role" })
}

resource "aws_iam_policy" "task_policy" {
  count       = var.task_policy != null ? 1 : 0
  name        = "${local.common_tags.Name}-task-policy"
  description = "Additional policy for the task role"
  policy      = var.task_policy
}

resource "aws_iam_role_policy_attachment" "task_policy" {
  count      = var.task_policy != null ? 1 : 0
  role       = aws_iam_role.task_role.name
  policy_arn = aws_iam_policy.task_policy[0].arn
}

resource "aws_iam_role" "task_execution_role" {
  name               = "${local.common_tags.Name}-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.task_assume_policy.json
  tags               = merge(local.tags, { Name = "${local.common_tags.Name}-task-execution-role" })
}

resource "aws_iam_role_policy_attachment" "task_execution_policy" {
  role       = aws_iam_role.task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_policy" "task_execution_policy_inline" {
  count       = var.task_execution_policy != null ? 1 : 0
  name        = "${local.common_tags.Name}-task-execution-policy"
  description = "Additional policy for the task execution role"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "task_execution_policy_inline" {
  count      = var.task_execution_policy != null ? 1 : 0
  role       = aws_iam_role.task_execution_role.name
  policy_arn = aws_iam_policy.task_execution_policy_inline[0].arn
}

# security group

resource "aws_security_group" "default" {
  vpc_id      = data.aws_vpc.selected.id
  name        = "${local.common_tags.Name}-service-sg"
  description = "Allow traffic to ${local.common_tags.Name} ECS service"
  tags        = merge(local.tags, { Name = "${local.common_tags.Name}-service-sg" })
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "allowed_cidrs" {
  count             = length(var.allowed_cidrs)
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  cidr_blocks       = var.allowed_cidrs
  security_group_id = aws_security_group.default.id
}

resource "aws_security_group_rule" "allowed_ports" {
  count             = length(var.allowed_ports)
  type              = "ingress"
  from_port         = var.allowed_ports[count.index]
  to_port           = var.allowed_ports[count.index]
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.default.id
}

resource "aws_security_group_rule" "external_security_groups" {
  count                    = length(var.allowed_security_groups)
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  source_security_group_id = var.allowed_security_groups[count.index]
  security_group_id        = aws_security_group.default.id
}

resource "aws_security_group_rule" "outgoing" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.default.id
}

# task

resource "aws_cloudwatch_log_group" "default" {
  name              = local.common_tags.Name
  retention_in_days = 3
  tags              = local.tags
}

resource "aws_ecs_task_definition" "core" {
  family                   = local.common_tags.Name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.container_cpu
  memory                   = var.container_mem
  execution_role_arn       = aws_iam_role.task_execution_role.arn
  task_role_arn            = aws_iam_role.task_role.arn
  container_definitions = jsonencode([{
    name        = "app-container"
    image       = "${var.container_image}:${var.container_tag}"
    essential   = true
    environment = var.container_environment
    linuxParameters = {
      initProcessEnabled = true
    }
    portMappings = [{
      name          = "name"
      protocol      = "tcp"
      containerPort = var.container_port
      hostPort      = var.container_port
      }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-region"        = var.region
        "awslogs-group"         = "name-app"
        "awslogs-stream-prefix" = "name-app"
      }
    }
    },
    {
      name  = "nginx"
      image = "image"
      portMappings = [
        {
          "containerPort" : 80,
          "hostPort" : 80,
          "protocol" : "tcp"
        }
      ]
      essential   = true
      environment = []
      mountPoints = []
      volumesFrom = []
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "name-app"
          "awslogs-region"        = "us-east-2"
          "awslogs-stream-prefix" = "nginx"
        }
      }
    }
  ])

  tags = merge(local.tags, { Name = "${local.common_tags.Name}-task" })

}

resource "aws_ecs_task_definition" "celery_worker" {
  family                   = local.worker.name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 1024
  memory                   = 2048
  execution_role_arn       = aws_iam_role.task_execution_role.arn
  task_role_arn            = aws_iam_role.task_role.arn
  container_definitions = jsonencode([{
    name       = "worker-container"
    image      = "${var.container_image}:${var.container_tag}"
    essential  = true
    entrypoint = ["celery", "-A", "name.celery", "worker", "-E"]
    linuxParameters = {
      initProcessEnabled = true
    }
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-create-group"  = "true"
        "awslogs-region"        = var.region
        "awslogs-group"         = aws_cloudwatch_log_group.default.name
        "awslogs-stream-prefix" = local.worker.name
      }
    }
  }])

  tags = merge(local.tags, { Name = "${local.common_tags.Name}-task" })

}

resource "aws_ecs_task_definition" "celery_scheduler" {
  family                   = local.scheduler.name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.container_cpu
  memory                   = var.container_mem
  execution_role_arn       = aws_iam_role.task_execution_role.arn
  task_role_arn            = aws_iam_role.task_role.arn
  container_definitions = jsonencode([{
    name       = "celery-scheduler-container"
    image      = "${var.container_image}:${var.container_tag}"
    essential  = true
    entrypoint = ["celery", "-A", "name.celery", "beat"]
    linuxParameters = {
      initProcessEnabled = true
    }
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-create-group"  = "true"
        "awslogs-region"        = var.region
        "awslogs-group"         = aws_cloudwatch_log_group.default.name
        "awslogs-stream-prefix" = local.scheduler.name
      }
    }
  }])

  tags = merge(local.tags, { Name = "${local.common_tags.Name}-task" })

}

resource "aws_ecs_task_definition" "celery_flower" {
  family                   = local.flower.name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.container_cpu
  memory                   = var.container_mem
  execution_role_arn       = aws_iam_role.task_execution_role.arn
  task_role_arn            = aws_iam_role.task_role.arn
  container_definitions = jsonencode([{
    name       = "celery-flower-container"
    image      = "${var.container_image}:${var.container_tag}"
    essential  = true
    entrypoint = ["celery", "-A", "name.celery", "flower", "--url-prefix=flower"]
    linuxParameters = {
      initProcessEnabled = true
    }
    portMappings = [{
      name          = "flower"
      protocol      = "tcp"
      containerPort = 5555
      hostPort      = 5555
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-create-group"  = "true"
        "awslogs-region"        = var.region
        "awslogs-group"         = aws_cloudwatch_log_group.default.name
        "awslogs-stream-prefix" = local.scheduler.name
      }
    }
  }])

  tags = merge(local.tags, { Name = "${local.common_tags.Name}-task" })

}
resource "aws_ecs_task_definition" "derivitec_task" {
  family                   = local.derivitec_task.name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.container_cpu
  memory                   = var.container_mem
  execution_role_arn       = aws_iam_role.task_execution_role.arn
  task_role_arn            = aws_iam_role.task_role.arn
  container_definitions = jsonencode([{
    name        = "${local.derivitec_task.name}-container"
    image       = "${var.container_image}:${var.container_tag}"
    essential   = true
    environment = var.container_environment
    entrypoint  = ["python", "manage.py", "derivitec_report"]
    linuxParameters = {
      initProcessEnabled = true
    }
    portMappings = [{
      protocol      = "tcp"
      containerPort = var.container_port
      hostPort      = var.container_port
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-create-group"  = "true"
        "awslogs-region"        = var.region
        "awslogs-group"         = aws_cloudwatch_log_group.default.name
        "awslogs-stream-prefix" = local.derivitec_task.name
      }
    }
  }])
  tags = merge(local.tags, { Name = "${local.derivitec_task.name}-task" })
}

resource "aws_ecs_task_definition" "margin_report_task" {
  family                   = local.margin_report_task.name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.container_cpu
  memory                   = var.container_mem
  execution_role_arn       = aws_iam_role.task_execution_role.arn
  task_role_arn            = aws_iam_role.task_role.arn
  container_definitions = jsonencode([{
    name        = "${local.derivitec_task.name}-container"
    image       = "${var.container_image}:${var.container_tag}"
    essential   = true
    environment = var.container_environment
    entrypoint  = ["python", "manage.py", "margin_report"]
    linuxParameters = {
      initProcessEnabled = true
    }
    portMappings = [{
      protocol      = "tcp"
      containerPort = var.container_port
      hostPort      = var.container_port
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-create-group"  = "true"
        "awslogs-region"        = var.region
        "awslogs-group"         = aws_cloudwatch_log_group.default.name
        "awslogs-stream-prefix" = local.margin_report_task.name
      }
    }
  }])
  tags = merge(local.tags, { Name = "${local.margin_report_task.name}-task" })
}

resource "aws_ecs_task_definition" "flex_option_task" {
  family                   = local.flex_option_task.name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.container_cpu
  memory                   = var.container_mem
  execution_role_arn       = aws_iam_role.task_execution_role.arn
  task_role_arn            = aws_iam_role.task_role.arn
  container_definitions = jsonencode([{
    name        = "${local.derivitec_task.name}-container"
    image       = "${var.container_image}:${var.container_tag}"
    essential   = true
    environment = var.container_environment
    entrypoint  = ["python", "manage.py", "flex_option_pricer"]
    linuxParameters = {
      initProcessEnabled = true
    }
    portMappings = [{
      protocol      = "tcp"
      containerPort = var.container_port
      hostPort      = var.container_port
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-create-group"  = "true"
        "awslogs-region"        = var.region
        "awslogs-group"         = aws_cloudwatch_log_group.default.name
        "awslogs-stream-prefix" = local.flex_option_task.name
      }
    }
  }])
  tags = merge(local.tags, { Name = "${local.flex_option_task.name}-task" })
}

# service

resource "aws_service_discovery_http_namespace" "default" {
  name = var.prefix
}

resource "aws_ecs_service" "core" {
  name                               = "${local.common_tags.Name}-service"
  cluster                            = var.ecs_cluster_id
  task_definition                    = aws_ecs_task_definition.core.arn
  desired_count                      = 1
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200
  launch_type                        = "FARGATE"
  scheduling_strategy                = "REPLICA"
  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_http_namespace.default.arn
    service {
      port_name = "app"
      client_alias {
        dns_name = "app"
        port     = 5005
      }
    }
  }
  network_configuration {
    security_groups  = [aws_security_group.default.id]
    subnets          = var.subnet_ids
    assign_public_ip = false
  }
  dynamic "load_balancer" {
    for_each = var.alb_listener_arn != null ? [1] : []
    content {
      target_group_arn = aws_lb_target_group.nginx.arn
      container_name   = "nginx"
      container_port   = 80
    }
  }
  enable_execute_command = var.enable_execute_command
  tags                   = merge(local.tags, { Name = "${local.common_tags.Name}-service" })
  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }
}

resource "aws_ecs_service" "celery_worker" {
  name                               = "celery-worker-service"
  cluster                            = var.ecs_cluster_id
  task_definition                    = aws_ecs_task_definition.celery_worker.arn
  desired_count                      = var.celery_worker_count
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200
  launch_type                        = "FARGATE"
  scheduling_strategy                = "REPLICA"
  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_http_namespace.default.arn
  }
  network_configuration {
    security_groups  = [aws_security_group.default.id]
    subnets          = var.subnet_ids
    assign_public_ip = false
  }
  tags                   = merge(local.tags, { Name = "${local.common_tags.Name}-service" })
  enable_execute_command = var.enable_execute_command
  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }
}

resource "aws_ecs_service" "celery_scheduler" {
  name                               = "celery-scheduler-service"
  cluster                            = var.ecs_cluster_id
  task_definition                    = aws_ecs_task_definition.celery_scheduler.arn
  desired_count                      = 1
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200
  launch_type                        = "FARGATE"
  scheduling_strategy                = "REPLICA"
  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_http_namespace.default.arn
  }
  network_configuration {
    security_groups  = [aws_security_group.default.id]
    subnets          = var.subnet_ids
    assign_public_ip = false
  }
  tags                   = merge(local.tags, { Name = "${local.common_tags.Name}-service" })
  enable_execute_command = var.enable_execute_command
  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }
}

resource "aws_ecs_service" "celery_flower" {
  name                               = "celery-flower-service"
  cluster                            = var.ecs_cluster_id
  task_definition                    = aws_ecs_task_definition.celery_flower.arn
  desired_count                      = 1
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200
  launch_type                        = "FARGATE"
  scheduling_strategy                = "REPLICA"
  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_http_namespace.default.arn
    service {
      port_name = "flower"
      client_alias {
        dns_name = "flower"
        port     = 5555
      }
    }
  }
  network_configuration {
    security_groups  = [aws_security_group.default.id]
    subnets          = var.subnet_ids
    assign_public_ip = false
  }
  tags                   = merge(local.tags, { Name = "${local.common_tags.Name}-flower-service" })
  enable_execute_command = var.enable_execute_command
  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }
}

# alb
resource "aws_lb_target_group" "nginx" {
  name        = "${local.common_tags.Name}-nginx-target-${substr(uuid(), 0, 3)}"
  port        = 5005
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.selected.id
  target_type = "ip"
  health_check {
    path                = var.alb_healthcheck_path
    protocol            = "HTTP"
    timeout             = var.alb_healthcheck_timeout
    interval            = var.alb_healthcheck_interval
    healthy_threshold   = 5
    unhealthy_threshold = 2
    matcher             = "200"
  }
  tags = merge(local.tags, { Name = "${local.common_tags.Name}-service-target" })

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [name]
  }
}

resource "aws_alb_listener_rule" "alb" {
  listener_arn = var.alb_listener_arn
  priority     = 2
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nginx.arn
  }
  condition {
    host_header {
      values = ["*${var.service_fqdn}"]
    }
  }
}
