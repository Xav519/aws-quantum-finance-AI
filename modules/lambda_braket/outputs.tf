output "function_arn" {
  description = "ARN of the Braket Lambda function"
  value       = aws_lambda_function.braket.arn
}

output "function_name" {
  description = "Name of the Braket Lambda function"
  value       = aws_lambda_function.braket.function_name
}