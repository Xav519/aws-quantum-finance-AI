# ==============================================================================
# modules/demo_frontend/outputs.tf
# ------------------------------------------------------------------------------
# PURPOSE
#   Values the `demo_frontend` module exposes to other modules.
#
# DETAILS
#   `demo_url` is the website address; `cloudfront_origin` feeds the API's CORS rule.
# ==============================================================================

output "demo_url" {
  description = "HTTPS URL of the demo frontend"
  value       = "https://${aws_cloudfront_distribution.frontend.domain_name}"
}

output "cloudfront_origin" {
  description = "Origin to allow in the API's CORS configuration"
  value       = "https://${aws_cloudfront_distribution.frontend.domain_name}"
}

output "distribution_id" {
  description = "CloudFront distribution ID (for cache invalidations)"
  value       = aws_cloudfront_distribution.frontend.id
}
