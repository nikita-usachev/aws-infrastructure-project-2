output "id" {
  description = "The ID of the ECS Cluster"
  value       = aws_ecs_cluster.default.id
}

output "arn" {
  description = "The ARN of the ECS Cluster"
  value       = aws_ecs_cluster.default.arn
}
