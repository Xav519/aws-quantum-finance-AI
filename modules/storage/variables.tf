variable "project" {
  description = "Project name prefix"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "results_retention_days" {
  description = "Days to keep raw Braket task results in S3"
  type        = number
  default     = 30
}
