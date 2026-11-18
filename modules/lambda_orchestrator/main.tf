# ==============================================================================
# modules/lambda_orchestrator/main.tf
# ------------------------------------------------------------------------------
# PURPOSE
#   Deploys the Orchestrator Lambda: the entry point behind POST /optimize.
#
# DETAILS
#   It validates the request and routes it: small problems (N <= 4) go to the
#   classical Lambda synchronously; N = 5 starts an asynchronous quantum job.
#   Creates: the function (zipped from src/) and its log group (7-day retention).
# ==============================================================================

locals {
  prefix        = "${var.project}-${var.environment}"
  function_name = "${local.prefix}-orchestrator"
}

# Packages src/ on every plan; the hash below triggers a redeploy on any code change.
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/build/lambda_orchestrator.zip"
  excludes    = ["**/__pycache__/**"]
}

# Created before the function so retention applies from the first invocation
# (otherwise Lambda auto-creates a never-expiring group and Terraform conflicts).
resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = var.log_retention_days
}

resource "aws_lambda_function" "orchestrator" {
  function_name    = local.function_name
  description      = "POST /optimize: validates and routes to classical (N<=${var.classical_threshold}) or quantum QAOA"
  role             = var.role_arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  architectures    = ["arm64"]
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  layers           = [var.layer_arn]
  timeout          = 30 # classical path waits for the classical Lambda (Bedrock call included)
  memory_size      = 256

  environment {
    variables = {
      DYNAMODB_TABLE           = var.dynamodb_table_name
      LAMBDA_CLASSICAL         = var.lambda_classical_name
      LAMBDA_BRAKET            = var.lambda_braket_name
      CLASSICAL_THRESHOLD      = tostring(var.classical_threshold)
      MAX_QUANTUM_JOBS_PER_DAY = tostring(var.max_quantum_jobs_per_day)
      QAOA_SHOTS               = tostring(var.qaoa_shots)
    }
  }

  depends_on = [aws_cloudwatch_log_group.this]

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}
