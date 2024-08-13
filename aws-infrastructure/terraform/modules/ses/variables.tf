variable "prefix" {
  type = string
}

variable "email_address" {
  type        = string
  description = "Email from which AWS SES will be able to send emails."
}
