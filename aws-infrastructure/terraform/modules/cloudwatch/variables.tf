variable "allowed_security_groups" {
  type    = list(string)
  default = []
}

variable "one_am_tue_sat" {
  type        = string
  description = "A 1 am cron expression"
}

variable "five_am_tue_sat" {
  type        = string
  description = "A 5 am cron expression"
}

variable "nine_am_mon_fri" {
  type        = string
  description = "A 9 am cron expression"
}

variable "ecs_derivitec_task_definition_arn" {
  type        = string
  description = "Derivitec report task definition arn"
}

variable "ecs_margin_report_task_definition_arn" {
  type        = string
  description = "Margin report task definition arn"
}

variable "ecs_flex_option_task_definition_arn" {
  type        = string
  description = "Flex option pricing task definition arn"
}

variable "task_execution_role_arn" {
  type = string
}

variable "cluster_arn" {
  type        = string
  description = "ECS Cluster ARN"
}

variable "ecs_subnets" {
  type        = list(any)
  description = "The subnets to run ecs tasks on"
}

variable "enabled" {
  default     = true
  type        = bool
  description = "Set to false to prevent the module from creating anything."
}

variable "is_enabled" {
  default     = true
  type        = bool
  description = "Whether the rule should be enabled."
}
