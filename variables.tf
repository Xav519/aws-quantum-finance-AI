variable "aws_region" {
  description = "Région AWS"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Nom du projet"
  type        = string
  default     = "quantum-finance"
}

variable "environment" {
  description = "Environnement"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Doit être dev, staging ou prod."
  }
}

variable "alert_email" {
  description = "Email pour alertes budget AWS"
  type        = string
}
