locals {
  prefix        = "${var.project}-${var.environment}"
  function_name = "${local.prefix}-braket"
  src_dir       = "${path.module}/src"
  zip_path      = "${path.module}/lambda_braket.zip"
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = local.src_dir
  output_path = local.zip_path
}

resource "aws_lambda_function" "braket" {
  function_name    = local.function_name
  description      = "QAOA circuit submission to Amazon Braket SV1 — real quantum task"
  role             = var.lambda_braket_role_arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  filename         = local.zip_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 300
  memory_size      = 512

  environment {
    variables = {
      DYNAMODB_TABLE    = var.dynamodb_table_name
      RESULTS_BUCKET    = var.results_bucket_name
      BEDROCK_MODEL     = "us.anthropic.claude-haiku-4-5-20251001-v1:0"
      BRAKET_DEVICE_ARN = "arn:aws:braket:::device/quantum-simulator/amazon/sv1"
    }
  }

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}