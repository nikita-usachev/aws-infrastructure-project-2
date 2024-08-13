output "name" {
  value       = aws_storagegateway_gateway.sgw.gateway_name
  description = "Storage Gateway Name"
}

output "id" {
  value       = aws_storagegateway_gateway.sgw.gateway_id
  description = "Storage Gateway ID"
}

output "share" {
  value       = aws_storagegateway_smb_file_share.smbshare.file_share_name
  description = "Storage Gateway SMB Share"
}
