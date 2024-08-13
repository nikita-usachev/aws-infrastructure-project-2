terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.13.1"
    }
  }
  required_version = ">= 1.3.3"
}

# data

data "aws_vpc" "selected" {
  id      = var.vpc_id
  default = var.vpc_id != null ? false : true
}

# security group

resource "aws_security_group" "cache" {
  name        = "${local.common_tags.Name}-sg"
  description = "ElastiCache Redis"
  vpc_id      = data.aws_vpc.selected.id

  tags = merge(local.tags, { Name = "${local.common_tags.Name}-sg" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "cache_allow_inbound" {
  count                    = length(var.security_groups) > 0 ? length(var.security_groups) : 0
  description              = "Inbound traffic from application"
  type                     = "ingress"
  from_port                = var.port
  to_port                  = var.port
  protocol                 = "tcp"
  source_security_group_id = var.security_groups[count.index]
  security_group_id        = aws_security_group.cache.id
}

resource "aws_security_group_rule" "cache_outbound" {
  description       = "Outbound traffic anywhere"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = [data.aws_vpc.selected.cidr_block]
  security_group_id = aws_security_group.cache.id
}

# cache

resource "aws_elasticache_subnet_group" "cache" {
  name       = local.common_tags.Name
  subnet_ids = var.private_subnet_ids
}

resource "aws_elasticache_parameter_group" "cache" {
  name   = local.common_tags.Name
  family = "redis${split(".", var.engine_version)[0]}"
  dynamic "parameter" {
    for_each = var.cache_parameters
    content {
      name  = parameter.value.name
      value = parameter.value.value
    }
  }
  dynamic "parameter" {
    for_each = var.cluster_enabled ? [1] : []
    content {
      name  = "cluster-enabled"
      value = "yes"
    }
  }
}

resource "aws_elasticache_replication_group" "cache" {
  replication_group_id = local.common_tags.Name
  description          = local.common_tags.Description
  engine               = "redis"
  parameter_group_name = aws_elasticache_parameter_group.cache.name
  engine_version       = var.engine_version
  node_type            = var.node_type
  port                 = var.port
  security_group_ids   = [aws_security_group.cache.id]
  subnet_group_name    = aws_elasticache_subnet_group.cache.name

  automatic_failover_enabled = var.cluster_enabled ? true : var.num_cache_nodes > 1 ? true : false
  multi_az_enabled           = var.multi_az_enabled

  num_cache_clusters      = !var.cluster_enabled ? var.num_cache_nodes : null
  num_node_groups         = var.cluster_enabled ? var.num_shards : null
  replicas_per_node_group = var.cluster_enabled ? var.num_replicas : null

  transit_encryption_enabled = var.auth_token != null ? true : var.transit_encryption_enabled
  auth_token                 = var.auth_token
  at_rest_encryption_enabled = true

  maintenance_window = var.maintenance_window
  snapshot_window    = var.snapshot_window

  tags = merge(local.tags, { Name = local.common_tags.Name })

  # Workaround for https://github.com/hashicorp/terraform-provider-aws/issues/15625
  # lifecycle {
  #   ignore_changes  = [engine_version]
  # }
}
