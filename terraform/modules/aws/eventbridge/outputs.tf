output "rule_arn" {
  description = "The Amazon Resource Name (ARN) of the EventBridge rule"
  value       = aws_cloudwatch_event_rule.rule.arn
}

output "rule_name" {
  description = "The name of the EventBridge rule"
  value       = aws_cloudwatch_event_rule.rule.name
}

output "target_id" {
  description = "The target ID of the EventBridge target"
  value       = aws_cloudwatch_event_target.target.target_id
}
