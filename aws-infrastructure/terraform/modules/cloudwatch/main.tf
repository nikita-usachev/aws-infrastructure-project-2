data "aws_iam_policy_document" "event_assume_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["events.amazonaws.com"]
      type        = "Service"
    }
  }
}

data "aws_iam_policy_document" "event_cloudwatch_policy" {
  statement {
    effect = "Allow"
    actions = [
      "ecs:RunTask",
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }
  statement {
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "scheduled_task_event_role" {
  name               = "scheduled-task-event-role"
  assume_role_policy = data.aws_iam_policy_document.event_assume_policy.json
}

resource "aws_iam_role_policy" "scheduled_task_event_role_policy" {
  name   = "scheduled-task-policy"
  role   = aws_iam_role.scheduled_task_event_role.id
  policy = data.aws_iam_policy_document.event_cloudwatch_policy.json
}

resource "aws_cloudwatch_event_rule" "one_am_tue_sat_rule" {
  name                = "one_am_tue_sat_rule"
  description         = "A rule to run at 1 am tue_sat"
  is_enabled          = var.is_enabled
  schedule_expression = var.one_am_tue_sat
}

resource "aws_cloudwatch_event_rule" "five_am_tue_sat_rule" {
  name                = "five_am_tue_sat_rule"
  description         = "A rule to run at 5 am tue_sat"
  is_enabled          = var.is_enabled
  schedule_expression = var.five_am_tue_sat
}

resource "aws_cloudwatch_event_rule" "nine_am_mon_fri_rule" {
  name                = "nine_am_mon_fri_rule"
  description         = "A rule to run at 8 am mon_fri"
  is_enabled          = var.is_enabled
  schedule_expression = var.nine_am_mon_fri
}

resource "aws_cloudwatch_event_target" "derivitec_ecs_task" {
  arn      = var.cluster_arn
  rule     = aws_cloudwatch_event_rule.five_am_tue_sat_rule.name
  role_arn = aws_iam_role.scheduled_task_event_role.arn
  ecs_target {
    launch_type         = "FARGATE"
    task_definition_arn = var.ecs_derivitec_task_definition_arn
    network_configuration {
      subnets          = var.ecs_subnets
      security_groups  = var.allowed_security_groups
      assign_public_ip = "false"
    }
  }
}

resource "aws_cloudwatch_event_target" "margin_report_ecs_task" {
  arn      = var.cluster_arn
  rule     = aws_cloudwatch_event_rule.nine_am_mon_fri_rule.name
  role_arn = aws_iam_role.scheduled_task_event_role.arn
  ecs_target {
    launch_type         = "FARGATE"
    task_definition_arn = var.ecs_margin_report_task_definition_arn
    network_configuration {
      subnets          = var.ecs_subnets
      security_groups  = var.allowed_security_groups
      assign_public_ip = "false"
    }
  }
}

resource "aws_cloudwatch_event_target" "flex_option_ecs_task" {
  arn      = var.cluster_arn
  rule     = aws_cloudwatch_event_rule.one_am_tue_sat_rule.name
  role_arn = aws_iam_role.scheduled_task_event_role.arn
  ecs_target {
    launch_type         = "FARGATE"
    task_definition_arn = var.ecs_flex_option_task_definition_arn
    network_configuration {
      subnets          = var.ecs_subnets
      security_groups  = var.allowed_security_groups
      assign_public_ip = "false"
    }
  }
}
