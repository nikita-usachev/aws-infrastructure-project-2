output "derivitec_task_arn" {
  value       = aws_ecs_task_definition.derivitec_task.arn
  description = "ARN of the derivitec report task"
}

output "margin_report_task_arn" {
  value       = aws_ecs_task_definition.margin_report_task.arn
  description = "ARN of the margin report task"
}

output "task_execution_role_arn" {
  value       = aws_iam_role.task_execution_role.arn
  description = "Role ARN for execution of the task"
}

output "flex_option_task_arn" {
  value       = aws_ecs_task_definition.flex_option_task.arn
  description = "ARN of the flex option pricing task"
}
