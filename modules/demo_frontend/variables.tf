variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "api_url" {
  description = "Base URL of the API Gateway (injected into the HTML)"
  type        = string
}