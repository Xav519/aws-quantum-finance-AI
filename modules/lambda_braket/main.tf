locals {
  prefix        = "${var.project}-${var.environment}"
  function_name = "${local.prefix}-braket"
}

# Packages src/ (handler.py + qaoa.py) on every plan.
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/build/lambda_braket.zip"
  excludes    = ["**/__pycache__/**"]
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = var.log_retention_days
}

resource "aws_lambda_function" "braket" {
  function_name    = local.function_name
  description      = "Submits the QAOA circuit to Amazon Braket and processes the result on completion"
  role             = var.role_arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  architectures    = ["arm64"]
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  layers           = [var.layer_arn]
  timeout          = 60
  memory_size      = 512

  environment {
    variables = {
      DYNAMODB_TABLE    = var.dynamodb_table_name
      RESULTS_BUCKET    = var.results_bucket_name
      BEDROCK_MODEL     = var.bedrock_model_id
      BRAKET_DEVICE_ARN = var.braket_device_arn
      PROJECT_TAG       = local.prefix
      QAOA_LAYERS       = tostring(var.qaoa_layers)
      QAOA_SHOTS        = tostring(var.qaoa_shots)
    }
  }

  depends_on = [aws_cloudwatch_log_group.this]

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

# Both invocation paths (orchestrator -> submit, EventBridge -> complete) are
# asynchronous. Handlers are idempotent, so one retry is safe; stale events
# are dropped after an hour.
resource "aws_lambda_function_event_invoke_config" "braket" {
  function_name                = aws_lambda_function.braket.function_name
  maximum_retry_attempts       = 1
  maximum_event_age_in_seconds = 3600
}
