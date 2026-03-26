output "eventbridge_rule_arn" {
  description = "ARN of the EventBridge rule for Braket job completion"
  value       = aws_cloudwatch_event_rule.braket_job_complete.arn
}

output "eventbridge_rule_name" {
  description = "Name of the EventBridge rule"
  value       = aws_cloudwatch_event_rule.braket_job_complete.name
}