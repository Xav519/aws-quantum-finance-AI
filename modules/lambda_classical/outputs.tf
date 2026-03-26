output "function_arn" {
  description = "ARN of the classical Lambda function"
  value       = aws_lambda_function.classical.arn
}

output "function_name" {
  description = "Name of the classical Lambda function"
  value       = aws_lambda_function.classical.function_name
}