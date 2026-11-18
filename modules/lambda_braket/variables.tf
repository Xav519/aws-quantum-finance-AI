# ==============================================================================
# modules/lambda_braket/variables.tf
# ------------------------------------------------------------------------------
# PURPOSE
#   Inputs of the `lambda_braket` module (values passed in from rootTerraformCode/main.tf).
#
# DETAILS
#   Each variable's `description` explains what it is used for.
# ==============================================================================

variable "project" {
  description = "Project name prefix"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "role_arn" {
  description = "Execution role ARN (Braket + S3 + Bedrock + DynamoDB)"
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

variable "results_bucket_name" {
  description = "S3 bucket Braket writes results to (must start with amazon-braket-)"
  type        = string
}

variable "bedrock_model_id" {
  description = "Bedrock model or inference-profile ID used for narratives"
  type        = string
}

variable "braket_device_arn" {
  description = "Braket device ARN (SV1 simulator by default)"
  type        = string
}

variable "qaoa_layers" {
  description = "QAOA depth p"
  type        = number
}

variable "qaoa_shots" {
  description = "Measurement shots per quantum task"
  type        = number
}

variable "log_retention_days" {
  description = "CloudWatch log retention"
  type        = number
  default     = 7
}
