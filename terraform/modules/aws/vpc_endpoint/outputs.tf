output "id" {
  description = "The ID of the VPC endpoint"
  value       = aws_vpc_endpoint.this.id
}

output "arn" {
  description = "The ARN of the VPC endpoint"
  value       = aws_vpc_endpoint.this.arn
}

output "cidr_blocks" {
  description = "The list of CIDR blocks for the exposed AWS service (Gateway endpoints)"
  value       = aws_vpc_endpoint.this.cidr_blocks
}

output "dns_entry" {
  description = "The DNS entries for the VPC Endpoint (Interface endpoints)"
  value       = aws_vpc_endpoint.this.dns_entry
}

output "network_interface_ids" {
  description = "One or more network interfaces for the VPC Endpoint (Interface endpoints)"
  value       = aws_vpc_endpoint.this.network_interface_ids
}

output "owner_id" {
  description = "The ID of the AWS account that owns the VPC endpoint"
  value       = aws_vpc_endpoint.this.owner_id
}

output "prefix_list_id" {
  description = "The prefix list ID of the exposed AWS service (Gateway endpoints)"
  value       = aws_vpc_endpoint.this.prefix_list_id
}

output "state" {
  description = "The state of the VPC endpoint"
  value       = aws_vpc_endpoint.this.state
}
