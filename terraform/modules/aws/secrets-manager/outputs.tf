output "name" {
  description = "The name of the secret"
  value       = aws_secretsmanager_secret.secret.name
}

output "arn" {
  description = "The ARN of the secret"
  value       = aws_secretsmanager_secret.secret.arn
}

output "id" {
  description = "The ID of the secret"
  value       = aws_secretsmanager_secret.secret.id
}
