# ==============================================================================
# modules/demo_frontend/variables.tf
# ------------------------------------------------------------------------------
# PURPOSE
#   Inputs of the `demo_frontend` module (values passed in from rootTerraformCode/main.tf).
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

variable "aws_region" {
  description = "Region of the API (used in the Content-Security-Policy)"
  type        = string
}

variable "api_url" {
  description = "Base URL of the HTTP API, written into config.js"
  type        = string
}
