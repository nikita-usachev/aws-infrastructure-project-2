terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.13.1"
    }
  }
  required_version = ">= 1.3.3"
}

resource "aws_ses_email_identity" "ses" {
  email    = var.email_address
}

data "aws_iam_policy_document" "ses" {
  statement {
    actions = [
      "ses:SendEmail",
      "ses:SendRawEmail",
    ]
    resources = [aws_ses_email_identity.ses.arn]
  }
}

resource "aws_iam_policy" "ses" {
  name   = "${var.prefix}-ses-send-email"
  policy = data.aws_iam_policy_document.ses.json
}
