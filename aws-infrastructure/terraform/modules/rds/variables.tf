variable "environment" {
  type = string
}

variable "allocated_storage" {
  type = number
}

variable "prefix" {
  type = string
}

variable "postgres_username" {
  type = string
}

variable "postgres_password" {
  type = string
}

variable "db_subnet_group_name" {
  type    = string
  default = "postgres-subnet"
}

variable "subnet_ids" {
  type = list(string)
}

variable "allowed_security_groups" {
  type = list(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}

locals {
  common_tags = {
    Environment   = var.environment
    Name          = "${var.prefix}-postgres"
    ProvisionedBy = "terraform"
  }
  tags = merge(var.tags, local.common_tags)
}
