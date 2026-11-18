# ==============================================================================
# modules/lambda_orchestrator/variables.tf
# ------------------------------------------------------------------------------
# PURPOSE
#   Inputs of the `lambda_orchestrator` module (values passed in from rootTerraformCode/main.tf).
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

variable "lambda_classical_name" {
  description = "Name of the classical solver Lambda"
  type        = string
}

variable "lambda_braket_name" {
  description = "Name of the Braket Lambda"
  type        = string
}

variable "classical_threshold" {
  description = "N <= this value uses the classical solver; larger N uses QAOA"
  type        = number
  default     = 4
}

variable "max_quantum_jobs_per_day" {
  description = "Daily cap on quantum jobs (cost guard for a public demo API)"
  type        = number
}

variable "qaoa_shots" {
  description = "Measurement shots per quantum task (reported in the 202 response)"
  type        = number
}

variable "log_retention_days" {
  description = "CloudWatch log retention"
  type        = number
  default     = 7
}
