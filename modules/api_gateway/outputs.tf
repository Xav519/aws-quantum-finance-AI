# ==============================================================================
# modules/api_gateway/outputs.tf
# ------------------------------------------------------------------------------
# PURPOSE
#   Values the `api_gateway` module exposes to other modules.
#
# DETAILS
#   Read in rootTerraformCode/main.tf as module.<name>.<output>.
# ==============================================================================

output "api_url" {
  description = "Base URL of the HTTP API"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "api_id" {
  description = "HTTP API ID (used for CloudWatch metrics)"
  value       = aws_apigatewayv2_api.main.id
}
