locals {
  prefix = "${var.project}-${var.environment}"
}

# ── SNS topic for alerts ──────────────────────────────────────────────────────
resource "aws_sns_topic" "alerts" {
  name = "${local.prefix}-alerts"
  tags = { Project = var.project, Environment = var.environment }
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ── CloudWatch Log Groups (explicit, 7-day retention) ─────────────────────────
resource "aws_cloudwatch_log_group" "orchestrator" {
  name              = "/aws/lambda/${var.lambda_orchestrator_name}"
  retention_in_days = 7
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

# ── CloudWatch Dashboard ──────────────────────────────────────────────────────
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${local.prefix}-dashboard"

  dashboard_body = jsonencode({
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

# ── Alarm: Orchestrator errors ────────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "orchestrator_errors" {
  alarm_name          = "${local.prefix}-orchestrator-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Orchestrator Lambda error detected"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    FunctionName = var.lambda_orchestrator_name
  }
}