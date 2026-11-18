# ==============================================================================
# rootTerraformCode/variables.tf
# ------------------------------------------------------------------------------
# PURPOSE
#   Every setting you can change for a deployment, with safe defaults.
#
# DETAILS
#   Set your own values in terraform.tfvars (see terraform.tfvars.example).
#   Only `alert_email` is required; everything else has a default.
# ==============================================================================

variable "aws_region" {
  description = "AWS region (Braket SV1 and the us.* Bedrock inference profile are available in us-east-1)"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project name, used as a prefix for every resource"
  type        = string
  default     = "quantum-finance"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging or prod."
  }
}

variable "alert_email" {
  description = "Email address that receives CloudWatch alarm notifications"
  type        = string
}

variable "bedrock_model_id" {
  description = "Bedrock model or cross-region inference-profile ID used for board narratives"
  type        = string
  default     = "us.anthropic.claude-haiku-4-5-20251001-v1:0"
}

variable "braket_device_arn" {
  description = "Braket device. SV1 (state-vector simulator) by default; see README before pointing this at a QPU"
  type        = string
  default     = "arn:aws:braket:::device/quantum-simulator/amazon/sv1"
}

variable "classical_threshold" {
  description = "Problem sizes N <= this value use the classical solver; larger N use QAOA"
  type        = number
  default     = 4
}

variable "qaoa_layers" {
  description = "QAOA depth p (linear-ramp schedule)"
  type        = number
  default     = 16

  validation {
    condition     = var.qaoa_layers >= 1 && var.qaoa_layers <= 24
    error_message = "qaoa_layers must be between 1 and 24."
  }
}

variable "qaoa_shots" {
  description = "Measurement shots per quantum task"
  type        = number
  default     = 1000

  validation {
    condition     = var.qaoa_shots >= 100 && var.qaoa_shots <= 10000
    error_message = "qaoa_shots must be between 100 and 10,000."
  }
}

variable "max_quantum_jobs_per_day" {
  description = "Daily cap on quantum jobs accepted by the public API (cost guard)"
  type        = number
  default     = 50
}

variable "extra_cors_origins" {
  description = "Additional browser origins allowed to call the API (e.g. http://localhost:8080 for local frontend work)"
  type        = list(string)
  default     = []
}
