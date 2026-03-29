locals {
  prefix = "${var.project}-${var.environment}"
}

# --- SNS: Notification Channel ---
# This serves as the 'Outbound' delivery system for system failures.
resource "aws_sns_topic" "alerts" {
  name = "${local.prefix}-alerts"
  tags = { Project = var.project, Environment = var.environment }
}

# Subscription: Sends an email to the address defined in your variables.
# Note: You must manually click the 'Confirm Subscription' link in the email after deployment.
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# --- CloudWatch: Log Management ---
# Explicitly defining log groups allows us to set a 'Retention Policy'.
# Without this, Lambda logs stay in AWS forever, incurring unnecessary costs.
resource "aws_cloudwatch_log_group" "orchestrator" {
  name              = "/aws/lambda/${var.lambda_orchestrator_name}"
  retention_in_days = 7 # Automatically deletes logs older than one week
}

resource "aws_cloudwatch_log_group" "classical" {
  name              = "/aws/lambda/${var.lambda_classical_name}"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "braket" {
  name              = "/aws/lambda/${var.lambda_braket_name}"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "get_job" {
  name              = "/aws/lambda/${var.lambda_get_job_name}"
  retention_in_days = 7
}

# --- CloudWatch: Operations Dashboard ---
# A centralized visual UI to monitor the health of the Hybrid Quantum/AI pipeline.
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${local.prefix}-dashboard"

  # The JSON body defines the layout of the graph widgets.
  dashboard_body = jsonencode({
    # Widget 1: Throughput (How many jobs are we running?)
    widgets = [
      {
        type = "metric"
        properties = {
          title  = "Lambda Invocations"
          region = var.aws_region  # FIX: required by CloudWatch dashboard API
          period = 60
          stat   = "Sum"
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", var.lambda_orchestrator_name],
            ["AWS/Lambda", "Invocations", "FunctionName", var.lambda_classical_name],
            ["AWS/Lambda", "Invocations", "FunctionName", var.lambda_braket_name],
            ["AWS/Lambda", "Invocations", "FunctionName", var.lambda_get_job_name],
          ]
        }
      },
      # Widget 2: Stability (Are any solvers crashing?)
      {
        type = "metric"
        properties = {
          title  = "Lambda Errors"
          region = var.aws_region
          period = 60
          stat   = "Sum"
          metrics = [
            ["AWS/Lambda", "Errors", "FunctionName", var.lambda_orchestrator_name],
            ["AWS/Lambda", "Errors", "FunctionName", var.lambda_classical_name],
            ["AWS/Lambda", "Errors", "FunctionName", var.lambda_braket_name],
          ]
        }
      },
      # Widget 3: Performance (Classical vs. Quantum Latency)
      {
        type = "metric"
        properties = {
          title  = "Lambda Duration (ms)"
          region = var.aws_region
          period = 60
          stat   = "Average"
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", var.lambda_orchestrator_name],
            ["AWS/Lambda", "Duration", "FunctionName", var.lambda_classical_name],
            ["AWS/Lambda", "Duration", "FunctionName", var.lambda_braket_name],
          ]
        }
      }
    ]
  })
}

# --- CloudWatch: Proactive Alerting ---
# Instead of watching the dashboard, this alarm 'pushes' a notification if 
# the Orchestrator fails.
resource "aws_cloudwatch_metric_alarm" "orchestrator_errors" {
  alarm_name          = "${local.prefix}-orchestrator-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1 # Trigger immediately after one failed period
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 1 # If errors >= 1, fire the SNS topic
  alarm_description   = "Orchestrator Lambda error detected"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    FunctionName = var.lambda_orchestrator_name
  }
}