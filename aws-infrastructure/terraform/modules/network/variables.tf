variable "enabled" {
  type    = bool
  default = false
}

variable "private_enabled" {
  type    = bool
  default = false
}

variable "endpoints_enabled" {
  type    = bool
  default = true
}

variable "nat_enabled" {
  type    = bool
  default = true
}

variable "region" {
  type = string
}

variable "environment" {
  type = string
}

variable "prefix" {
  type = string
}

variable "suffix" {
  type    = string
  default = ""
}

variable "vpc_cidr" {
  type    = string
  default = "10.10.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.10.0.0/24", "10.10.1.0/24", "10.10.2.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.10.4.0/24", "10.10.5.0/24", "10.10.6.0/24"]
}

variable "avail_zones" {
  default = 2
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
  tags = merge(var.tags, local.common_tags)
}
