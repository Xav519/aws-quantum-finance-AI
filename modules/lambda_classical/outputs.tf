# ==============================================================================
# modules/lambda_classical/outputs.tf
# ------------------------------------------------------------------------------
# PURPOSE
#   Values the `lambda_classical` module exposes to other modules.
#
# DETAILS
#   Read in rootTerraformCode/main.tf as module.<name>.<output>.
# ==============================================================================

output "function_arn" {
  description = "Lambda function ARN"
  value       = aws_lambda_function.classical.arn
}

output "function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.classical.function_name
}