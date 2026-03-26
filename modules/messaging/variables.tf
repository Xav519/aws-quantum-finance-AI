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