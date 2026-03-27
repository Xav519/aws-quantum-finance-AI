variable "project" {
  description = "Project name prefix"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. dev, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region — passed through to CloudWatch dashboard widget properties"
  type        = string
}

variable "alert_email" {
  description = "Email address for SNS alarm notifications"
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
