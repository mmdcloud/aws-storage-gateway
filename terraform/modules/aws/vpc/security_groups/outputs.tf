output "id" {
  description = "The ID of the security group"
  value       = aws_security_group.security_group.id
}

output "arn" {
  description = "The ARN of the security group"
  value       = aws_security_group.security_group.arn
}

