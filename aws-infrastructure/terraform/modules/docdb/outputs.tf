output "id" {
  description = "The DocumentDB Cluster Identifier"
  value       = aws_docdb_cluster.default.id
}

output "endpoint" {
  description = "The DNS address of the DocumentDB instance"
  value       = aws_docdb_cluster.default.endpoint
}

output "reader_endpoint" {
  description = "A read-only endpoint for the DocumentDB cluster, automatically load-balanced across replicas"
  value       = aws_docdb_cluster.default.reader_endpoint
}
