variable "project" {
  description = "Project name prefix"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "role_arn" {
  description = "Execution role ARN"
  type        = string
}

variable "layer_arn" {
  description = "ARN of the shared qf_common layer"
  type        = string
}

variable "dynamodb_table_name" {
  description = "DynamoDB jobs table name"
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch log retention"
  type        = number
  default     = 7
}
