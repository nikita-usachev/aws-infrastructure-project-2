output "port" {
  description = "The Redis port"
  value       = var.enabled ? var.port : null
}

output "id" {
  description = "The Redis Cluster Identifier"
  value       = aws_elasticache_replication_group.cache.replication_group_id
}

output "primary_endpoint" {
  description = "The Redis cluster primary endpoint"
  value       = var.enabled && !var.cluster_enabled ? aws_elasticache_replication_group.cache.primary_endpoint_address : null
}

output "reader_endpoint" {
  description = "The Redis cluster reader endpoint"
  value       = var.enabled && !var.cluster_enabled ? aws_elasticache_replication_group.cache.reader_endpoint_address : null
}

output "configuration_endpoint" {
  description = "The Redis cluster configuration endpoint"
  value       = var.enabled && var.cluster_enabled ? aws_elasticache_replication_group.cache.configuration_endpoint_address : null
}
