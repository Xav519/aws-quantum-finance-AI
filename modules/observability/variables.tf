variable "project" {
  description = "Project name prefix"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "aws_region" {
  description = "AWS region, required by CloudWatch dashboard widgets"
  type        = string
}

variable "alert_email" {
  description = "Email address that receives alarm notifications"
  type        = string
}

variable "api_id" {
  description = "HTTP API ID"
  type        = string
}

variable "lambda_orchestrator_name" {
  description = "Name of the orchestrator Lambda function"
  type        = string
}

variable "lambda_classical_name" {
  description = "Name of the classical Lambda function"
  type        = string
}

variable "lambda_braket_name" {
  description = "Name of the Braket Lambda function"
  type        = string
}

variable "lambda_get_job_name" {
  description = "Name of the get-job Lambda function"
  type        = string
}
