# ==============================================================================
# modules/lambda_braket/outputs.tf
# ------------------------------------------------------------------------------
# PURPOSE
#   Values the `lambda_braket` module exposes to other modules.
#
# DETAILS
#   Read in rootTerraformCode/main.tf as module.<name>.<output>.
# ==============================================================================

output "function_arn" {
  description = "Lambda function ARN"
  value       = aws_lambda_function.braket.arn
}

output "function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.braket.function_name
}