output "orchestrator_role_arn" {
  description = "Execution role ARN for the orchestrator Lambda"
  value       = aws_iam_role.orchestrator.arn
}

output "classical_role_arn" {
  description = "Execution role ARN for the classical Lambda"
  value       = aws_iam_role.classical.arn
}

output "braket_role_arn" {
  description = "Execution role ARN for the Braket Lambda"
  value       = aws_iam_role.braket.arn
}

output "get_job_role_arn" {
  description = "Execution role ARN for the get-job Lambda"
  value       = aws_iam_role.get_job.arn
}
