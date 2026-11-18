variable "project" {
  description = "Project name prefix"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "lambda_orchestrator_arn" {
  description = "ARN of the orchestrator Lambda"
  type        = string
}

variable "lambda_orchestrator_name" {
  description = "Name of the orchestrator Lambda"
  type        = string
}

variable "lambda_get_job_arn" {
  description = "ARN of the get-job Lambda"
  type        = string
}

variable "lambda_get_job_name" {
  description = "Name of the get-job Lambda"
  type        = string
}

variable "cors_allowed_origins" {
  description = "Origins allowed to call the API from a browser"
  type        = list(string)
}

variable "throttle_burst_limit" {
  description = "Stage-wide burst limit (requests)"
  type        = number
  default     = 20
}

variable "throttle_rate_limit" {
  description = "Stage-wide steady-state limit (requests/second)"
  type        = number
  default     = 10
}

variable "optimize_burst_limit" {
  description = "Burst limit for POST /optimize"
  type        = number
  default     = 5
}

variable "optimize_rate_limit" {
  description = "Steady-state limit for POST /optimize (requests/second)"
  type        = number
  default     = 1
}

variable "log_retention_days" {
  description = "CloudWatch log retention for access logs"
  type        = number
  default     = 7
}
