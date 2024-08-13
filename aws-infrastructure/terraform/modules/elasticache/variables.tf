variable "allowed_security_groups" {
  type        = list(string)
  description = "Security group ids for use with cluster"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnet ids associated with the cluster"
}

variable "environment" {
  type        = string
  default     = null
  description = "Environment name aka terraform workspace."
}

variable "prefix" {
  type        = string
  default     = "jcash-"
  description = "Environment prefix, is used in resources name generation."
}

variable "suffix" {
  type        = string
  default     = "-dev"
  description = "Environment suffix, is used in resources name generation."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "A map of tags to apply for the resources."
}

locals {
  common_tags = {
    environment   = var.environment
    provisionedby = "terraform"
  }
  tags = merge(var.tags, local.common_tags)
}
