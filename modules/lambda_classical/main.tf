# ==============================================================================
# modules/lambda_classical/main.tf
# ------------------------------------------------------------------------------
# PURPOSE
#   Deploys the Classical Lambda: the exact solver for small problems (N <= 4).
#
# DETAILS
#   It checks every possible assignment, computes the greedy baseline, asks
#   Bedrock for a board summary and stores the result.
#   Creates: the function (zipped from src/) and its log group (7-day retention).
# ==============================================================================

locals {
  prefix        = "${var.project}-${var.environment}"
  function_name = "${local.prefix}-classical"
}

# Packages src/ on every plan; the hash below triggers a redeploy on any code change.
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/build/lambda_classical.zip"
  excludes    = ["**/__pycache__/**"]
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = var.log_retention_days
}

resource "aws_lambda_function" "classical" {
  function_name    = local.function_name
  description      = "Exact (N!) assignment solver + greedy baseline + Bedrock board narrative"
  role             = var.role_arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  architectures    = ["arm64"]
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  layers           = [var.layer_arn]
  timeout          = 25 # must stay below the orchestrator's 30 s timeout
  memory_size      = 256

  environment {
    variables = {
      DYNAMODB_TABLE = var.dynamodb_table_name
      BEDROCK_MODEL  = var.bedrock_model_id
    }
  }

  depends_on = [aws_cloudwatch_log_group.this]

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}
