# ==============================================================================
# modules/shared_layer/variables.tf
# ------------------------------------------------------------------------------
# PURPOSE
#   Inputs of the `shared_layer` module (values passed in from rootTerraformCode/main.tf).
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
