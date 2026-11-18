variable "project" {
  description = "Project name prefix"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "aws_region" {
  description = "Region the Lambdas run in (used to build scoped ARNs)"
  type        = string
}

variable "jobs_table_arn" {
  description = "ARN of the DynamoDB jobs table"
  type        = string
}

variable "results_bucket_arn" {
  description = "ARN of the Braket results bucket"
  type        = string
}

variable "bedrock_model_id" {
  description = "Bedrock model or inference-profile ID used for narratives"
  type        = string
}
