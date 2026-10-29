# =============================================================================
# Production-Grade Terraform Outputs
# =============================================================================

# --- Storage Gateway Appliance Endpoints ---

output "gateway_private_ip" {
  description = "Private IP address of the Storage Gateway EC2 instance in the private subnet"
  value       = module.gateway_instance.private_ip
}

output "gateway_ip_address" {
  description = "Alias for gateway_private_ip for backward compatibility"
  value       = module.gateway_instance.private_ip
}

output "gateway_id" {
  description = "Unique Identifier of the AWS Storage Gateway appliance"
  value       = module.storage_gateway.id
}

output "gateway_arn" {
  description = "Amazon Resource Name (ARN) of the AWS Storage Gateway appliance"
  value       = module.storage_gateway.arn
}

output "storagegateway_vpc_endpoint_id" {
  description = "ID of the AWS Storage Gateway Interface VPC Endpoint"
  value       = aws_vpc_endpoint.storagegateway.id
}

output "storagegateway_vpc_endpoint_dns" {
  description = "Regional non-zonal DNS name of the AWS Storage Gateway Interface VPC Endpoint"
  value       = local.sgw_vpce_dns
}

output "s3_vpc_endpoint_id" {
  description = "ID of the Amazon S3 Gateway VPC Endpoint"
  value       = aws_vpc_endpoint.s3.id
}

# --- Amazon S3 Target Bucket ---

output "s3_bucket_name" {
  description = "Target Amazon S3 bucket backing the Storage Gateway SMB share"
  value       = module.s3_bucket.bucket
}

output "s3_bucket_arn" {
  description = "ARN of the Amazon S3 bucket backing the Storage Gateway SMB share"
  value       = module.s3_bucket.arn
}

# --- SMB File Share & Mounting ---

output "smb_share_arns" {
  description = "List of ARNs for the Storage Gateway SMB File Shares"
  value       = module.storage_gateway.smb_share_arns
}

output "smb_mount_command" {
  description = "Production mount command to execute on the on-premise client to mount SMB share with SMB 3.0 encryption"
  value       = "sudo /home/admin/mount-aws-storage-gateway.sh ${module.gateway_instance.private_ip} ${module.s3_bucket.bucket} ${var.smb_guest_password}"
  sensitive   = true
}

# --- GCP Simulated On-Premise Client ---

output "source_vm_name" {
  description = "Hostname/Name of the GCP simulated on-premise VM"
  value       = var.gcp_vm_name
}

output "source_vm_public_ip" {
  description = "Public IP address of the GCP simulated on-premise VM for SSH management"
  value       = google_compute_address.source_vm_ip.address
}

# --- Cross-Cloud HA VPN & BGP Network Details ---

output "vpn_connection_ids" {
  description = "AWS VPN Connection IDs connecting AWS VGW to GCP Cloud Router"
  value = [
    aws_vpn_connection.vpn_conn_0.id,
    aws_vpn_connection.vpn_conn_1.id
  ]
}

output "vpn_tunnel_details" {
  description = "Detailed map of the 4 active IPsec tunnels between GCP Cloud Router and AWS VGW"
  value = {
    "tunnel_0_1" = {
      aws_outside_ip = aws_vpn_connection.vpn_conn_0.tunnel1_address
      inside_cidr    = var.vpn_tunnel_inside_cidrs["0-1"]
      aws_inside_ip  = aws_vpn_connection.vpn_conn_0.tunnel1_vgw_inside_address
      gcp_inside_ip  = aws_vpn_connection.vpn_conn_0.tunnel1_cgw_inside_address
    }
    "tunnel_0_2" = {
      aws_outside_ip = aws_vpn_connection.vpn_conn_0.tunnel2_address
      inside_cidr    = var.vpn_tunnel_inside_cidrs["0-2"]
      aws_inside_ip  = aws_vpn_connection.vpn_conn_0.tunnel2_vgw_inside_address
      gcp_inside_ip  = aws_vpn_connection.vpn_conn_0.tunnel2_cgw_inside_address
    }
    "tunnel_1_1" = {
      aws_outside_ip = aws_vpn_connection.vpn_conn_1.tunnel1_address
      inside_cidr    = var.vpn_tunnel_inside_cidrs["1-1"]
      aws_inside_ip  = aws_vpn_connection.vpn_conn_1.tunnel1_vgw_inside_address
      gcp_inside_ip  = aws_vpn_connection.vpn_conn_1.tunnel1_cgw_inside_address
    }
    "tunnel_1_2" = {
      aws_outside_ip = aws_vpn_connection.vpn_conn_1.tunnel2_address
      inside_cidr    = var.vpn_tunnel_inside_cidrs["1-2"]
      aws_inside_ip  = aws_vpn_connection.vpn_conn_1.tunnel2_vgw_inside_address
      gcp_inside_ip  = aws_vpn_connection.vpn_conn_1.tunnel2_cgw_inside_address
    }
  }
}
