# ==============================================================================
# modules/shared_layer/outputs.tf
# ------------------------------------------------------------------------------
# PURPOSE
#   Values the `shared_layer` module exposes to other modules.
#
# DETAILS
#   `layer_arn`: attached to all four Lambda functions.
# ==============================================================================

output "layer_arn" {
  description = "Versioned ARN of the shared qf_common layer"
  value       = aws_lambda_layer_version.common.arn
}
