# backend

terraform {
  backend "s3" {
    bucket  = "terraform-states-bucket-name"
    key     = "dev"
    region  = "us-east-2"
    encrypt = true
  }
  required_providers {
    ansible = {
      source  = "nbering/ansible"
      version = "1.0.4"
    }
  }
}
