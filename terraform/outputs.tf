output "gateway_ip_address" {
  description = "Public IP address of the Storage Gateway instance"
  value       = module.storage_gateway.gateway_ip_address
}

output "gateway_id" {
  description = "AWS Storage Gateway ID"
  value       = module.storage_gateway.id
}

output "gateway_arn" {
  description = "AWS Storage Gateway ARN"
  value       = module.storage_gateway.arn
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
  description = "Sample command to run on the GCP simulated on-premise VM to mount the SMB file share"
  value       = "sudo /home/admin/mount-aws-storage-gateway.sh ${module.gateway_instance.public_ip} ${module.s3_bucket.bucket} ${var.smb_guest_password}"
  sensitive   = true
}
