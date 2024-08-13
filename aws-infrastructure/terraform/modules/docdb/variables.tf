variable "environment" {
}

variable "prefix" {
}

variable "suffix" {
}

variable "vpc_id" {
  type = string
}

variable "avail_zones" {
  default = null
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "instance_class" {
  type    = string
  default = "db.t4g.medium"
}

variable "instance_count" {
  type    = number
  default = 1
}

variable "instance_start_index" {
  type    = number
  default = 1
}

variable "instance_performance_insights" {
  type    = bool
  default = null
}

variable "storage_encrypted" {
  type    = bool
  default = true
}

variable "engine_version" {
  type    = string
  default = "5.0.0"
}

variable "engine" {
  type    = string
  default = "docdb"
}

variable "security_group_description" {
  type    = string
  default = "DocumentDB"
}

variable "master_username" {
  type = string
}

variable "master_password" {
  type = string
}

variable "port" {
  default = 27017
}

variable "security_groups" {
  type    = list(any)
  default = []
}

variable "backup_retention" {
  type    = number
  default = 7
}

variable "snapshot_identifier" {
  type    = string
  default = null
}

variable "skip_final_snapshot" {
  type    = bool
  default = null
}

variable "apply_immediately" {
  type    = bool
  default = null
}

variable "deletion_protection" {
  type    = bool
  default = null
}

variable "parameters_additional" {
  type    = list(map(string))
  default = []
}

variable "maintenance_window" {
  type    = string
  default = "sun:02:00-sun:04:00"
}

variable "parameters_default" {
  type = list(map(string))
  default = [
    {
      name  = "tls"
      value = "enabled"
    }
  ]
}

variable "cloudwatch_logs_exports" {
  default = null
}

variable "tags" {
  default = {}
}

locals {
  common_tags = {
    Environment   = var.environment
    Name          = "${var.prefix}${var.suffix}"
    ProvisionedBy = "terraform"
  }
  tags       = merge(var.tags, local.common_tags)
  parameters = concat(var.parameters_default, var.parameters_additional)
}
