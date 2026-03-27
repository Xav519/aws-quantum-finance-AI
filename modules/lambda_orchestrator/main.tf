
locals {
  prefix        = "${var.project}-${var.environment}"
  function_name = "${local.prefix}-orchestrator"
  src_dir       = "${path.module}/src"
  zip_path      = "${path.module}/lambda_orchestrator.zip"
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = local.src_dir
  output_path = local.zip_path
}

resource "aws_lambda_function" "orchestrator" {
  function_name    = local.function_name
  description = "Routes optimization requests: classical (N=2..4) or quantum QAOA on Braket SV1 (N=5)"
  role             = var.lambda_role_arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  filename         = local.zip_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 90
  memory_size      = 256

// Updated with newest values
  environment {
  variables = {
    LAMBDA_CLASSICAL    = var.lambda_classical_name
    LAMBDA_BRAKET       = var.lambda_braket_name
    CLASSICAL_THRESHOLD = tostring(var.classical_threshold)
    DYNAMODB_TABLE      = var.dynamodb_table_name
    BEDROCK_MODEL       = "us.anthropic.claude-haiku-4-5-20251001-v1:0"
  }
}

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}