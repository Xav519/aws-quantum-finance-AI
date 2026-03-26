output "function_arn" {
  value = aws_lambda_function.get_job.arn
}

output "function_name" {
  value = aws_lambda_function.get_job.function_name
}