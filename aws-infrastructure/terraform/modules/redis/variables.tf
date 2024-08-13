variable "enabled" {
  default = true
  type    = bool
}

variable "environment" {
  type = string
}

variable "prefix" {
  type = string
}

variable "suffix" {
  type = string
}

variable "engine_version" {
  type    = string
  default = "7.0"
}

variable "cluster_enabled" {
  default = true
  type    = bool
}

variable "multi_az_enabled" {
  default = false
  type    = bool
}

variable "node_type" {
  type    = string
  default = "cache.t3.micro"
}

variable "num_cache_nodes" {
  type    = number
  default = 1
}

variable "num_replicas" {
  type    = number
  default = 1
}

variable "num_shards" {
  type    = number
  default = 1
}

variable "transit_encryption_enabled" {
  type    = bool
  default = true
}

variable "auth_token" {
  type    = string
  default = null
}

variable "maintenance_window" {
  default = "sun:03:00-sun:05:00"
  type    = string
}

variable "snapshot_window" {
  default = "01:00-02:00"
  type    = string
}

variable "cache_parameters" {
  type    = list(map(string))
  default = []
}

variable "port" {
  type    = number
  default = 6379
}

variable "security_groups" {
  type    = list(any)
  default = []
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "tags" {
  default = {}
  type    = map(any)
}

locals {
  common_tags = {
    Environment   = var.environment
    Name          = "${var.prefix}${var.suffix}"
    Description   = "ElastiCache Redis Cluster for ${var.prefix}"
    ProvisionedBy = "terraform"
  }
  tags = merge(var.tags, local.common_tags)
}
