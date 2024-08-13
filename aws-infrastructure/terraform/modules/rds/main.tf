resource "aws_db_instance" "default" {
  allocated_storage      = var.allocated_storage
  db_name                = "name"
  engine                 = "postgres"
  engine_version         = "14.7"
  instance_class         = "db.t3.micro"
  identifier             = local.common_tags.Name
  username               = var.postgres_username
  password               = var.postgres_password
  vpc_security_group_ids = var.allowed_security_groups
  skip_final_snapshot    = true
  db_subnet_group_name   = aws_db_subnet_group.default.name
  deletion_protection    = true
  port                   = "5432"
  tags                   = local.tags
}


resource "aws_db_subnet_group" "default" {
  name       = var.db_subnet_group_name
  subnet_ids = var.subnet_ids
  tags       = merge(local.tags, { Name = "${local.common_tags.Name}-cert" })
}
