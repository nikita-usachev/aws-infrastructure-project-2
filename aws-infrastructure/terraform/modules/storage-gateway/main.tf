resource "aws_cloudwatch_log_group" "swg" {
  name              = "${local.common_tags.Name}-cloudwatch"
  retention_in_days = 7
  tags              = merge(local.tags, { Name = "${local.common_tags.Name}-cloudwatch" })
}

resource "aws_storagegateway_gateway" "sgw" {
  gateway_ip_address       = var.gateway_ip_address
  gateway_name             = var.gateway_name
  gateway_timezone         = var.gateway_timezone
  gateway_type             = var.gateway_type
  gateway_vpc_endpoint     = var.vpce_enabled ? aws_vpc_endpoint.sgw_vpce[0].dns_entry[0].dns_name : null
  cloudwatch_log_group_arn = aws_cloudwatch_log_group.swg.arn
  smb_guest_password       = var.smb_guest_password
  tags                     = merge(local.tags, { Name = local.common_tags.Name })
  depends_on               = [aws_vpc_endpoint.sgw_vpce]
}

data "aws_storagegateway_local_disk" "sgw" {
  gateway_arn = aws_storagegateway_gateway.sgw.arn
  disk_node   = var.disk_node
  disk_path   = var.disk_path
}

resource "aws_storagegateway_cache" "sgw" {
  disk_id     = data.aws_storagegateway_local_disk.sgw.disk_id
  gateway_arn = aws_storagegateway_gateway.sgw.arn

  lifecycle {
    ignore_changes = [
      disk_id
    ]
  }
}

# share

resource "aws_storagegateway_smb_file_share" "smbshare" {
  file_share_name       = "${local.common_tags.Name}-smb"
  authentication        = "GuestAccess"
  gateway_arn           = aws_storagegateway_gateway.sgw.arn
  location_arn          = var.bucket_arn
  default_storage_class = "S3_STANDARD"
  role_arn              = aws_iam_role.sgw.arn
  audit_destination_arn = aws_cloudwatch_log_group.swg.arn
  tags                  = merge(local.tags, { Name = "${local.common_tags.Name}-smb" })
}

# iam

data "aws_caller_identity" "current" {
}

data "aws_iam_policy_document" "sgw" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["storagegateway.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [aws_storagegateway_gateway.sgw.id]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_iam_policy" "sgw" {
  name = "${local.common_tags.Name}-smb-policy"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : [
          "s3:GetAccelerateConfiguration",
          "s3:GetBucketLocation",
          "s3:GetBucketVersioning",
          "s3:ListBucket",
          "s3:ListBucketVersions",
          "s3:ListBucketMultipartUploads"
        ],
        "Resource" : "${var.bucket_arn}",
        "Effect" : "Allow"
      },
      {
        "Action" : [
          "s3:AbortMultipartUpload",
          "s3:DeleteObject",
          "s3:DeleteObjectVersion",
          "s3:GetObject",
          "s3:GetObjectAcl",
          "s3:GetObjectVersion",
          "s3:ListMultipartUploadParts",
          "s3:PutObject",
          "s3:PutObjectAcl"
        ],
        "Resource" : "${var.bucket_arn}/*",
        "Effect" : "Allow"
      }
    ]
  })
}

resource "aws_iam_role" "sgw" {
  name               = "${local.common_tags.Name}-smb-role"
  assume_role_policy = data.aws_iam_policy_document.sgw.json
}

resource "aws_iam_role_policy_attachment" "sgw" {
  role       = aws_iam_role.sgw.name
  policy_arn = aws_iam_policy.sgw.arn
}

resource "aws_security_group" "vpce_sg" {
  description = "Storage Gateway VPC Endpoint connectivity"
  vpc_id      = var.vpc_id
  name        = "${local.common_tags.Name}-vpce-sg"
  tags        = merge(local.tags, { Name = "${local.common_tags.Name}-vpce-sg" })
}

resource "aws_security_group_rule" "incoming" {
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.vpce_sg.id
}

resource "aws_security_group_rule" "outgoing" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.vpce_sg.id
}

resource "aws_vpc_endpoint" "sgw_vpce" {
  count               = var.vpce_enabled ? 1 : 0
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.storagegateway"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.vpce_sg.id]
  subnet_ids          = var.subnet_ids
  private_dns_enabled = false
  tags                = merge(local.tags, { Name = "${local.common_tags.Name}-vpce" })
}
