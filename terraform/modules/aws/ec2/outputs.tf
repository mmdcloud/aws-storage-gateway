output "id" {
  description = "The ID of the EC2 instance"
  value       = aws_instance.instance.id
}

output "public_ip" {
  description = "The public IP of the EC2 instance"
  value       = aws_instance.instance.public_ip
}

output "private_ip" {
  description = "The private IP of the EC2 instance"
  value       = aws_instance.instance.private_ip
}

output "arn" {
  description = "The ARN of the EC2 instance"
  value       = aws_instance.instance.arn
}
