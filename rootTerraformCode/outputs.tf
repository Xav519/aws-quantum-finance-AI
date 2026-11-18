output "demo_url" {
  description = "HTTPS URL of the demo frontend (CloudFront)"
  value       = module.demo_frontend.demo_url
}

output "api_url" {
  description = "Base URL of the HTTP API"
  value       = module.api_gateway.api_url
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID (for cache invalidations)"
  value       = module.demo_frontend.distribution_id
}

output "dynamodb_table" {
  description = "DynamoDB table for job records"
  value       = module.storage.dynamodb_table_name
}

output "results_bucket" {
  description = "S3 bucket where Braket writes task results"
  value       = module.storage.results_bucket_name
}

output "lambda_functions" {
  description = "Lambda function names"
  value = {
    orchestrator = module.lambda_orchestrator.function_name
    classical    = module.lambda_classical.function_name
    braket       = module.lambda_braket.function_name
    get_job      = module.lambda_get_job.function_name
  }
}

output "eventbridge_rule" {
  description = "EventBridge rule that routes Braket task completions to the Braket Lambda"
  value       = module.messaging.eventbridge_rule_name
}

output "cloudwatch_dashboard" {
  description = "CloudWatch dashboard name"
  value       = module.observability.dashboard_name
}
