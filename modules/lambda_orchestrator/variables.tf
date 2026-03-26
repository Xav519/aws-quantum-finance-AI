
variable "project"               { type = string }
variable "environment"           { type = string }
variable "lambda_role_arn"       { type = string }
variable "lambda_classical_name" { type = string }
variable "lambda_braket_name"    { type = string }
variable "dynamodb_table_name"   { type = string }

variable "classical_threshold" {
  description = "N <= this value uses classical brute-force. N > this uses quantum QAOA."
  type        = number
  default     = 4
}
