output "id" {
  description = "The ID of the storage gateway"
  value       = aws_storagegateway_gateway.file_gateway.id
}

output "arn" {
  description = "The ARN of the storage gateway"
  value       = aws_storagegateway_gateway.file_gateway.arn
}

output "gateway_ip_address" {
  description = "The IP address of the storage gateway"
  value       = aws_storagegateway_gateway.file_gateway.gateway_ip_address
}

output "smb_share_ids" {
  description = "List of SMB file share IDs"
  value       = aws_storagegateway_smb_file_share.smb_share[*].id
}

output "smb_share_arns" {
  description = "List of SMB file share ARNs"
  value       = aws_storagegateway_smb_file_share.smb_share[*].arn
}

output "nfs_share_ids" {
  description = "List of NFS file share IDs"
  value       = aws_storagegateway_nfs_file_share.file_share[*].id
}

output "nfs_share_arns" {
  description = "List of NFS file share ARNs"
  value       = aws_storagegateway_nfs_file_share.file_share[*].arn
}
