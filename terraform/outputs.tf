output "gateway_ip_address" {
  description = "Private IP address of the Storage Gateway EC2 instance"
  value       = module.gateway_instance.private_ip
}

output "gateway_private_ip" {
  description = "Private IP address of the Storage Gateway EC2 instance"
  value       = module.gateway_instance.private_ip
}

output "gateway_id" {
  description = "AWS Storage Gateway ID"
  value       = module.storage_gateway.id
}

output "gateway_arn" {
  description = "AWS Storage Gateway ARN"
  value       = module.storage_gateway.arn
}

output "storagegateway_vpc_endpoint_dns" {
  description = "DNS name of the AWS Storage Gateway Interface VPC Endpoint"
  value       = local.sgw_vpce_dns
}

output "source_vm_public_ip" {
  description = "Public IP address of the GCP simulated on-premise VM"
  value       = google_compute_address.source_vm_ip.address
}

output "s3_bucket_name" {
  description = "S3 Bucket backing the Storage Gateway"
  value       = module.s3_bucket.bucket
}

output "smb_share_arns" {
  description = "Storage Gateway SMB File Share ARNs"
  value       = module.storage_gateway.smb_share_arns
}

output "smb_mount_command" {
  description = "Command to run on the GCP simulated on-premise VM to mount the SMB file share privately over VPN"
  value       = "sudo /home/admin/mount-aws-storage-gateway.sh ${module.gateway_instance.private_ip} ${module.s3_bucket.bucket} ${var.smb_guest_password}"
  sensitive   = true
}

output "vpn_connection_ids" {
  description = "AWS VPN Connection IDs connecting AWS VGW to GCP Cloud Router"
  value = [
    aws_vpn_connection.vpn_conn_0.id,
    aws_vpn_connection.vpn_conn_1.id
  ]
}
