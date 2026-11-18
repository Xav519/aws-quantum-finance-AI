output "api_url" {
  description = "Base URL of the HTTP API"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "api_id" {
  description = "HTTP API ID (used for CloudWatch metrics)"
  value       = aws_apigatewayv2_api.main.id
}
