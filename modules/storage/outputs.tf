output "results_bucket_name" {
  description = "Name of the S3 bucket for Braket results"
  value       = aws_s3_bucket.braket_results.bucket
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB jobs table"
  value       = aws_dynamodb_table.jobs.name
}

output "results_bucket_arn" {
  description = "ARN of the S3 bucket for Braket results"
  value       = aws_s3_bucket.braket_results.arn
}

output "jobs_table_name" {
  description = "Name of the DynamoDB table for job status"
  value       = aws_dynamodb_table.jobs.name
}

output "jobs_table_arn" {
  description = "ARN of the DynamoDB table for job status"
  value       = aws_dynamodb_table.jobs.arn
}
