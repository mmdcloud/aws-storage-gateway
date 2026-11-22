output "arn" {
  description = "The Amazon Resource Name (ARN) identifying your Lambda Function"
  value       = aws_lambda_function.function.arn
}

output "function_name" {
  description = "The unique name of your Lambda Function"
  value       = aws_lambda_function.function.function_name
}

output "name" {
  description = "The unique name of your Lambda Function (alias for function_name)"
  value       = aws_lambda_function.function.function_name
}

output "id" {
  description = "The ID of the Lambda function"
  value       = aws_lambda_function.function.id
}
