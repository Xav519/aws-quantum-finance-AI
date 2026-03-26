output "api_url" {
  description = "Base URL of the API Gateway — use this in Postman or curl to test"
  value       = module.api_gateway.api_url
}

output "demo_url" {
  description = "Public URL of the S3-hosted demo frontend"
  value       = module.demo_frontend.demo_url
}

output "dynamodb_table" {
  description = "DynamoDB table name for job tracking"
  value       = module.storage.dynamodb_table_name
}

output "results_bucket" {
  description = "S3 bucket name where Braket circuit results are stored"
  value       = module.storage.results_bucket_name
}

output "lambda_orchestrator" {
  description = "Orchestrator Lambda function name"
  value       = module.lambda_orchestrator.function_name
}

output "lambda_classical" {
  description = "Classical brute-force Lambda function name"
  value       = module.lambda_classical.function_name
}

output "lambda_braket" {
  description = "Quantum QAOA Lambda function name"
  value       = module.lambda_braket.function_name
}

output "lambda_get_job" {
  description = "Get-job status Lambda function name"
  value       = module.lambda_get_job.function_name
}

output "cloudwatch_dashboard" {
  description = "CloudWatch dashboard name — open in AWS console to monitor all Lambdas"
  value       = module.observability.dashboard_name
}

output "eventbridge_rule" {
  description = "EventBridge rule that triggers Lambda Braket on Braket task completion"
  value       = module.messaging.eventbridge_rule_name
}