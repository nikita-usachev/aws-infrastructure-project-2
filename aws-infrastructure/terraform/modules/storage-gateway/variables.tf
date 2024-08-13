variable "gateway_name" {
  type        = string
  description = "Storage Gateway Name"
}

variable "smb_guest_password" {
  type        = string
  default     = null
}

variable "gateway_ip_address" {
  type        = string
  description = "IP Address of the Storage Gateway"
  default     = null
}

variable "gateway_timezone" {
  type        = string
  description = "Time zone for the gateway. The time zone is of the format GMT, GMT-hr:mm, or GMT+hr:mm.For example, GMT-4:00 indicates the time is 4 hours behind GMT. Avoid prefixing with 0"
  default     = "GMT"
}

variable "timeout_in_seconds" {
  type        = number
  sensitive   = false
  default     = -1
  description = "Specifies the time in seconds, in which the JoinDomain operation must complete. The default is 20 seconds."
}

variable "gateway_type" {
  type        = string
  description = "Type of the gateway"
  default     = "FILE_S3"
}

variable "disk_path" {
  default     = "/dev/sdb"
  type        = string
  description = "Disk path on the Storage Gateway VM where the cache disk resides on the OS"
}

variable "disk_node" {
  default     = "/dev/sdb"
  type        = string
  description = "Disk node on the Storage Gateway VM where the cache disk resides on the OS"
}

variable "bucket_name" {
  type = string
}

variable "bucket_arn" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "region" {
}

variable "environment" {
}

variable "tags" {
  default = {}
}

variable "vpce_enabled" {
  type    = bool
  default = true
}

locals {
  common_tags = {
    Environment   = var.environment
    Name          = var.gateway_name
    ProvisionedBy = "terraform"
  }
  tags = merge(var.tags, local.common_tags)
}
