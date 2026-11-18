output "layer_arn" {
  description = "Versioned ARN of the shared qf_common layer"
  value       = aws_lambda_layer_version.common.arn
}
