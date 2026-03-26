variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "lambda_braket_role_arn" {
  description = "IAM role ARN with Braket + S3 + Bedrock + DynamoDB permissions"
  type        = string
}

variable "dynamodb_table_name" {
  type = string
}

variable "results_bucket_name" {
  type = string
}