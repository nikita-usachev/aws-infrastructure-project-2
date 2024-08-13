variable "region" {
  default = "us-east-2"
}

variable "dev_account_id" {
  type = string
}

variable "prod_account_id" {
  type = string
}

variable "aws_profile" {
  default = null
}

variable "prefix" {
  default = "app"
}

variable "environment" {
  default = null
}

variable "key_path_public" {
  default = "~/.ssh/id_rsa.pub"
}

variable "key_path_private" {
  default = "~/.ssh/id_rsa"
}

variable "network_enabled" {
  default = false
}

variable "vpc_cidr" {
  default = null
}

variable "private_subnet_cidrs" {
  default = null
}

variable "public_subnet_cidrs" {
  default = null
}

variable "vpn_enabled" {
  default = true
}

variable "vpn_client_cidr" {
  default = ""
}

variable "vpn_clients" {
  default = []
}

variable "instance_ami_owner" {
  default = ""
}

variable "instance_ami_pattern" {
  default = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
}

variable "username" {
  default = "ubuntu"
}

variable "external_ip_list" {
  type    = list(any)
  default = ["0.0.0.0/0"]
}

variable "external_port_list" {
  type    = list(any)
  default = [80, 443]
}

variable "az_count" {
  default = 2
}

variable "az_count_network" {
  default = 2
}

variable "private" {
  default = false
}

variable "private_nat" {
  default = true
}

variable "vpc_id" {
  default = null
}

variable "dns_enabled" {
  type    = bool
  default = false
}

variable "dns_zone" {
  type    = string
  default = ""
}

variable "one_am_tue_sat" {
  type    = string
  default = ""
}

variable "five_am_tue_sat" {
  type    = string
  default = ""
}

variable "nine_am_mon_fri" {
  type    = string
  default = ""
}

variable "gitlab_enabled" {
  type    = bool
  default = false
}

variable "dns_force_destroy" {
  default = true
}

variable "dns_internal_only" {
  type    = bool
  default = true
}

variable "dns_create_records_ext" {
  type    = bool
  default = true
}

variable "dns_create_records_int" {
  type    = bool
  default = true
}

variable "rds_db_username" {
  type    = string
  default = "root"
}

variable "rds_db_password" {
  type    = string
  default = "root"
}

variable "rds_db_allocated_storage" {
  type    = number
  default = 10
}

variable "backups_enabled" {
  type    = bool
  default = false
}

variable "backups_schedule" {
  default = {
    interval      = 24
    interval_unit = "HOURS"
    times         = ["23:45"]
  }
}

variable "backups_retain_count" {
  type    = number
  default = 7
}

variable "docdb_clusters" {
  type = list(object({
    name                    = string
    instance_class          = optional(string)
    instance_count          = optional(number)
    engine                  = optional(string)
    engine_version          = optional(string)
    dns_prefix              = optional(string)
    master_username         = optional(string)
    master_password         = optional(string)
    parameters              = optional(list(map(string)))
    cloudwatch_logs_exports = optional(list(string))
    security_groups         = optional(list(string))
    backup_retention        = optional(number)
    deletion_protection     = optional(bool)
    skip_final_snapshot     = optional(bool)
    snapshot_identifier     = optional(string)
  }))
  default = []
}

variable "ecr_repositories" {
  type = list(object({
    name = string
  }))
  default = []
}

# Example of instance group definition
# ec2_instances = {
#   bastion = {
#     count       = 1
#     type        = "t3.micro"
#     disk_size   = 20
#     ami_pattern = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
#     spot_price  = 0.01
#   }
#   app = {
#     count       = 2
#     type        = "t3.micro"
#     disk_size   = 30
#     ami_pattern = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
#   }
# }
variable "ec2_instances" {
  type    = map(any)
  default = {}
}

variable "ipsec_connections" {
  type = list(object({
    name             = string
    ip_address       = optional(string)
    local_cidr       = optional(string)
    remote_cidr      = optional(string)
    static_routes    = optional(list(string))
    use_attached_vpg = optional(bool)
  }))
  default = []
}

variable "gitlab_cache_bucket_enabled" {
  default = false
}

locals {
  environment = var.environment != null ? var.environment : "${terraform.workspace}"
  suffix      = ""
}
