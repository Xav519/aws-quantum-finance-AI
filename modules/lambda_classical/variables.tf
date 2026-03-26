variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "lambda_role_arn" {
  description = "IAM role ARN for the classical Lambda"
  type        = string
}

variable "dynamodb_table_name" {
  description = "DynamoDB table name for logging results"
  type        = string
}