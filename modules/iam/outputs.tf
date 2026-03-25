output "lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_role.arn
}

output "lambda_braket_role_arn" {
  description = "ARN of the Lambda Braket role"
  value       = aws_iam_role.lambda_braket_role.arn
}
