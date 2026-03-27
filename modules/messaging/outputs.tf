output "eventbridge_rule_arn" {
  description = "ARN of the EventBridge rule that triggers Lambda Braket on task completion"
  value       = aws_cloudwatch_event_rule.braket_task_complete.arn
}

output "eventbridge_rule_name" {
  description = "Name of the EventBridge rule"
  value       = aws_cloudwatch_event_rule.braket_task_complete.name
}