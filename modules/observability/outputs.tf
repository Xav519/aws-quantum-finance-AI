# ==============================================================================
# modules/observability/outputs.tf
# ------------------------------------------------------------------------------
# PURPOSE
#   Values the `observability` module exposes to other modules.
#
# DETAILS
#   Read in rootTerraformCode/main.tf as module.<name>.<output>.
# ==============================================================================

output "sns_topic_arn" {
  value = aws_sns_topic.alerts.arn
}

output "dashboard_name" {
  value = aws_cloudwatch_dashboard.main.dashboard_name
}