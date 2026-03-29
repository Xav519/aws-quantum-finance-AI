locals {
  prefix = "${var.project}-${var.environment}"
}

# -- HTTP API (v2) --
# This is the core API Gateway container (v2 supports HTTP APIs, which are faster and cheaper than REST APIs)
resource "aws_apigatewayv2_api" "main" {
  name          = "${local.prefix}-api"
  protocol_type = "HTTP"
  description   = "Quantum Finance Optimizer API"

  # CORS configuration allows web browsers to make requests from different domains
  cors_configuration {
    allow_origins = ["*"] # Allows all origins; restrict this in production for better security
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["Content-Type", "Authorization"]
    max_age       = 300 # How long the browser should cache these CORS settings (in seconds)
  }

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

# -- Stage --
# Defines the deployment stage. The "$default" name means the API is accessible at the base URL.
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true # Automatically pushes changes to the API when the configuration is updated

  # Configures structured JSON logging to CloudWatch for monitoring and debugging
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

# CloudWatch Log Group where API traffic logs are stored
resource "aws_cloudwatch_log_group" "api_logs" {
  name              = "/aws/apigateway/${local.prefix}"
  retention_in_days = 7 # Keep logs for a week to manage storage costs
}

# -- Integrations --
# Integrations connect specific routes to backend services (Lambda functions in this case)

# Integration for the Orchestrator Lambda (handles the heavy lifting)
resource "aws_apigatewayv2_integration" "orchestrator" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = var.lambda_orchestrator_arn
  payload_format_version = "2.0"
}

# Integration for the Get Job Lambda (handles status checks)
resource "aws_apigatewayv2_integration" "get_job" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = var.lambda_get_job_arn
  payload_format_version = "2.0"
}

# -- Routes --
# Routes map specific HTTP methods and paths to the integrations defined above

# POST /optimize -> Calls Orchestrator
resource "aws_apigatewayv2_route" "post_optimize" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /optimize"
  target    = "integrations/${aws_apigatewayv2_integration.orchestrator.id}"
}

# GET /jobs/{job_id} -> Calls Get Job (includes path parameter support)
resource "aws_apigatewayv2_route" "get_job" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /jobs/{job_id}"
  target    = "integrations/${aws_apigatewayv2_integration.get_job.id}"
}

# -- Lambda permissions --
# These resources explicitly "allow" API Gateway to invoke your Lambda functions.
# Without these, you will get a 500 "Internal Server Error" because of missing permissions.

# Permission for Orchestrator Lambda
resource "aws_lambda_permission" "apigw_orchestrator" {
  statement_id  = "AllowAPIGatewayInvokeOrchestrator"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_orchestrator_name
  principal     = "apigateway.amazonaws.com"
  # Restricts invocation to only this specific API Gateway for security
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

# Permission for Get Job Lambda
resource "aws_lambda_permission" "apigw_get_job" {
  statement_id  = "AllowAPIGatewayInvokeGetJob"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_get_job_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}