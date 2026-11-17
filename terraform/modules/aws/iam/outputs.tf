output "arn" {
  description = "The Amazon Resource Name (ARN) of the IAM role"
  value       = aws_iam_role.role.arn
}

output "name" {
  description = "The name of the IAM role"
  value       = aws_iam_role.role.name
}

output "id" {
  description = "The ID of the IAM role"
  value       = aws_iam_role.role.id
}

output "policy_arn" {
  description = "The ARN of the custom policy if created"
  value       = length(aws_iam_policy.policy) > 0 ? aws_iam_policy.policy[0].arn : null
}
