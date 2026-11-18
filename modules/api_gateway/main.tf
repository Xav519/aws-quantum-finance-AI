locals {
  prefix = "${var.project}-${var.environment}"
}

# =============================================================================
# HTTP API (API Gateway v2)
# =============================================================================
resource "aws_apigatewayv2_api" "main" {
  name          = "${local.prefix}-api"
  protocol_type = "HTTP"
  description   = "Quantum-ready incident response optimizer API"

  # Browsers may only call the API from the demo frontend. API Gateway handles
  # preflight and overrides any CORS headers the Lambdas might return.
  cors_configuration {
    allow_origins = var.cors_allowed_origins
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["content-type"]
    max_age       = 300
  }

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "api_logs" {
  name              = "/aws/apigateway/${local.prefix}"
  retention_in_days = var.log_retention_days
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true

  # Throttling is the first line of defence for a public, unauthenticated demo:
  # every POST can trigger a Bedrock call, and N = 5 a billed Braket task.
  # The orchestrator additionally enforces a daily quantum-job quota.
  default_route_settings {
    throttling_burst_limit = var.throttle_burst_limit
    throttling_rate_limit  = var.throttle_rate_limit
  }

  route_settings {
    route_key              = aws_apigatewayv2_route.post_optimize.route_key
    throttling_burst_limit = var.optimize_burst_limit
    throttling_rate_limit  = var.optimize_rate_limit
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_logs.arn
    format = jsonencode({
      requestId        = "$context.requestId"
      sourceIp         = "$context.identity.sourceIp"
      requestTime      = "$context.requestTime"
      httpMethod       = "$context.httpMethod"
      routeKey         = "$context.routeKey"
      status           = "$context.status"
      protocol         = "$context.protocol"
      responseLength   = "$context.responseLength"
      latencyMs        = "$context.responseLatency"
      errorMessage     = "$context.error.message"
      integrationError = "$context.integrationErrorMessage"
    })
  }
}

# =============================================================================
# Integrations and routes
# =============================================================================
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

# =============================================================================
# Lambda permissions: only these routes on this API may invoke
# =============================================================================
resource "aws_lambda_permission" "apigw_orchestrator" {
  statement_id  = "AllowAPIGatewayInvokeOrchestrator"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_orchestrator_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/POST/optimize"
}

resource "aws_lambda_permission" "apigw_get_job" {
  statement_id  = "AllowAPIGatewayInvokeGetJob"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_get_job_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/GET/jobs/*"
}
