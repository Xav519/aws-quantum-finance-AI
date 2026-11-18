# ==============================================================================
# modules/storage/variables.tf
# ------------------------------------------------------------------------------
# PURPOSE
#   Inputs of the `storage` module (values passed in from rootTerraformCode/main.tf).
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

variable "results_retention_days" {
  description = "Days to keep raw Braket task results in S3"
  type        = number
  default     = 30
}
