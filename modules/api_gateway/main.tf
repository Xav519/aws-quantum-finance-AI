locals {
  prefix = "${var.project}-${var.environment}"
}

# ── HTTP API (v2) ─────────────────────────────────────────────────────────────
resource "aws_apigatewayv2_api" "main" {
  name          = "${local.prefix}-api"
  protocol_type = "HTTP"
  description   = "Quantum Finance Optimizer API"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["Content-Type", "Authorization"]
    max_age       = 300
  }

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

# ── Stage ─────────────────────────────────────────────────────────────────────
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_logs.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      sourceIp       = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
      errorMessage   = "$context.error.message"
    })
  }
}

resource "aws_cloudwatch_log_group" "api_logs" {
  name              = "/aws/apigateway/${local.prefix}"
  retention_in_days = 7
}

# ── Integrations ──────────────────────────────────────────────────────────────
resource "aws_apigatewayv2_integration" "orchestrator" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = var.lambda_orchestrator_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "get_job" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = var.lambda_get_job_arn
  payload_format_version = "2.0"
}

# ── Routes ────────────────────────────────────────────────────────────────────
resource "aws_apigatewayv2_route" "post_optimize" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /optimize"
  target    = "integrations/${aws_apigatewayv2_integration.orchestrator.id}"
}

resource "aws_apigatewayv2_route" "get_job" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /jobs/{job_id}"
  target    = "integrations/${aws_apigatewayv2_integration.get_job.id}"
}

# ── Lambda permissions ────────────────────────────────────────────────────────
resource "aws_lambda_permission" "apigw_orchestrator" {
  statement_id  = "AllowAPIGatewayInvokeOrchestrator"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_orchestrator_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_get_job" {
  statement_id  = "AllowAPIGatewayInvokeGetJob"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_get_job_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}