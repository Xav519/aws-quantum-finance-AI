# ==============================================================================
# modules/lambda_get_job/outputs.tf
# ------------------------------------------------------------------------------
# PURPOSE
#   Values the `lambda_get_job` module exposes to other modules.
#
# DETAILS
#   Read in rootTerraformCode/main.tf as module.<name>.<output>.
# ==============================================================================

output "function_arn" {
  description = "Lambda function ARN"
  value       = aws_lambda_function.get_job.arn
}

output "function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.get_job.function_name
}