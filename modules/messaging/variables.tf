# ==============================================================================
# modules/messaging/variables.tf
# ------------------------------------------------------------------------------
# PURPOSE
#   Inputs of the `messaging` module (values passed in from rootTerraformCode/main.tf).
#
# DETAILS
#   Each variable's `description` explains what it is used for.
# ==============================================================================

variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "lambda_braket_arn" {
  description = "ARN of the Lambda Braket function (EventBridge target)"
  type        = string
}

variable "lambda_braket_name" {
  description = "Name of the Lambda Braket function (for permission)"
  type        = string
}