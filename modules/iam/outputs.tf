output "lambda_role_arn" {
  description = "ARN du rôle Lambda standard"
  value       = aws_iam_role.lambda_role.arn
}

output "lambda_braket_role_arn" {
  description = "ARN du rôle Lambda Braket"
  value       = aws_iam_role.lambda_braket_role.arn
}
