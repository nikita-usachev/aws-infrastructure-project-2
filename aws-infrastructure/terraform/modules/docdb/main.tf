# data

data "aws_vpc" "selected" {
  id      = var.vpc_id
  default = var.vpc_id != null ? false : true
}

# security group

resource "aws_security_group" "default" {
  name        = "${local.common_tags.Name}-sg"
  description = var.security_group_description
  vpc_id      = data.aws_vpc.selected.id

  tags = merge(local.tags, { Name = "${local.common_tags.Name}-sg" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "inbound" {
  count                    = length(var.security_groups) > 0 ? length(var.security_groups) : 0
  description              = "Inbound traffic from instances"
  type                     = "ingress"
  from_port                = var.port
  to_port                  = var.port
  protocol                 = "tcp"
  source_security_group_id = var.security_groups[count.index]
  security_group_id        = aws_security_group.default.id
}

resource "aws_security_group_rule" "outbound" {
  description       = "Outbound traffic anywhere"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.default.id
}

# parameters

resource "aws_docdb_cluster_parameter_group" "default" {
  name   = local.common_tags.Name
  family = "${var.engine}${split(".", var.engine_version)[0]}.${split(".", var.engine_version)[1]}"
  tags   = merge(local.tags, { Name = local.common_tags.Name })

  dynamic "parameter" {
    for_each = local.parameters
    content {
      name         = parameter.value.name
      value        = parameter.value.value
      apply_method = lookup(parameter.value, "apply_method", null)
    }
  }
}

resource "aws_docdb_subnet_group" "default" {
  name       = local.common_tags.Name
  subnet_ids = var.private_subnet_ids
  tags       = merge(local.tags, { Name = local.common_tags.Name })
}

# cluster

resource "aws_docdb_cluster" "default" {
  cluster_identifier              = local.common_tags.Name
  master_username                 = var.master_username
  master_password                 = var.master_password
  port                            = var.port
  engine                          = var.engine
  engine_version                  = var.engine_version
  storage_encrypted               = var.storage_encrypted
  availability_zones              = var.avail_zones
  vpc_security_group_ids          = [aws_security_group.default.id]
  db_subnet_group_name            = aws_docdb_subnet_group.default.name
  db_cluster_parameter_group_name = aws_docdb_cluster_parameter_group.default.name
  skip_final_snapshot             = var.skip_final_snapshot
  final_snapshot_identifier       = "${local.common_tags.Name}-final-snapshot"
  backup_retention_period         = var.backup_retention
  snapshot_identifier             = var.snapshot_identifier
  enabled_cloudwatch_logs_exports = var.cloudwatch_logs_exports
  apply_immediately               = var.apply_immediately
  deletion_protection             = var.deletion_protection
  preferred_maintenance_window    = var.maintenance_window
  lifecycle {
    ignore_changes = [
      snapshot_identifier,
      engine_version
    ]
  }
  tags = merge(local.tags, { Name = local.common_tags.Name })
}

resource "aws_docdb_cluster_instance" "default" {
  count                        = var.instance_count
  identifier                   = "${local.common_tags.Name}-${count.index + var.instance_start_index}"
  cluster_identifier           = aws_docdb_cluster.default.id
  instance_class               = var.instance_class
  enable_performance_insights  = var.instance_performance_insights
  preferred_maintenance_window = var.maintenance_window
  tags                         = merge(local.tags, { Name = "${local.common_tags.Name}-${count.index + var.instance_start_index}" })
}
