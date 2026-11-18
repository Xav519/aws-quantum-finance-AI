locals {
  prefix = "${var.project}-${var.environment}"

  functions = {
    orchestrator = var.lambda_orchestrator_name
    classical    = var.lambda_classical_name
    braket       = var.lambda_braket_name
    get_job      = var.lambda_get_job_name
  }

  lambda_metric = { for metric in ["Invocations", "Errors", "Duration", "Throttles"] :
    metric => [for name in values(local.functions) : ["AWS/Lambda", metric, "FunctionName", name]]
  }
}

# --- SNS: alert channel ---------------------------------------------------------
# Confirm the subscription from the email AWS sends after the first apply.
# Note: not encrypted with the AWS-managed aws/sns key on purpose; CloudWatch
# alarms cannot publish to topics using it (a customer-managed key would work).
resource "aws_sns_topic" "alerts" {
  name = "${local.prefix}-alerts"
  tags = { Project = var.project, Environment = var.environment }
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# Lambda log groups (with retention) live next to each function in its module.

# --- Alarms -------------------------------------------------------------------
# Any error in a function is worth an email for a demo with this traffic level.
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  for_each = local.functions

  alarm_name          = "${local.prefix}-${each.key}-errors"
  alarm_description   = "${each.value} reported at least one error"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  dimensions          = { FunctionName = each.value }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "api_5xx" {
  alarm_name          = "${local.prefix}-api-5xx"
  alarm_description   = "The HTTP API returned 5xx responses"
  namespace           = "AWS/ApiGateway"
  metric_name         = "5xx"
  dimensions          = { ApiId = var.api_id, Stage = "$default" }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}

# --- Dashboard ----------------------------------------------------------------
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${local.prefix}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric", x = 0, y = 0, width = 12, height = 6
        properties = {
          title   = "Lambda invocations", region = var.aws_region, period = 60, stat = "Sum"
          metrics = local.lambda_metric["Invocations"]
        }
      },
      {
        type = "metric", x = 12, y = 0, width = 12, height = 6
        properties = {
          title   = "Lambda errors", region = var.aws_region, period = 60, stat = "Sum"
          metrics = local.lambda_metric["Errors"]
        }
      },
      {
        type = "metric", x = 0, y = 6, width = 12, height = 6
        properties = {
          title   = "Lambda duration p90 (ms)", region = var.aws_region, period = 60, stat = "p90"
          metrics = local.lambda_metric["Duration"]
        }
      },
      {
        type = "metric", x = 12, y = 6, width = 12, height = 6
        properties = {
          title = "API requests and errors", region = var.aws_region, period = 60, stat = "Sum"
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiId", var.api_id, "Stage", "$default"],
            ["AWS/ApiGateway", "4xx", "ApiId", var.api_id, "Stage", "$default"],
            ["AWS/ApiGateway", "5xx", "ApiId", var.api_id, "Stage", "$default"],
          ]
        }
      },
    ]
  })
}
