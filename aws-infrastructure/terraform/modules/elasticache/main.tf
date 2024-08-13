resource "aws_elasticache_cluster" "redis" {
  cluster_id               = "redis"
  engine                   = "redis"
  node_type                = "cache.t4g.small"
  num_cache_nodes          = 1
  parameter_group_name     = "default.redis7"
  snapshot_retention_limit = 4
  engine_version           = "7.0"
  port                     = 6379
  security_group_ids       = var.allowed_security_groups
  subnet_group_name        = aws_elasticache_subnet_group.redis_subnets.name
  tags                     = merge(local.tags, { Name = "${var.prefix}${var.suffix}-gitlab-runner" })
}

resource "aws_elasticache_subnet_group" "redis_subnets" {
  name       = "redis-subnet-group"
  subnet_ids = var.subnet_ids
}
