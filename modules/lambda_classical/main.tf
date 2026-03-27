locals {
  prefix        = "${var.project}-${var.environment}"
  function_name = "${local.prefix}-classical"
  src_dir       = "${path.module}/src"
  zip_path      = "${path.module}/lambda_classical.zip"
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = local.src_dir
  output_path = local.zip_path
}

resource "aws_lambda_function" "classical" {
  function_name    = local.function_name
  description      = "Brute-force assignment optimizer with Bedrock humanization"
  role             = var.lambda_role_arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  filename         = local.zip_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 60
  memory_size      = 256

  environment {
    variables = {
      DYNAMODB_TABLE = var.dynamodb_table_name
      BEDROCK_MODEL  = "anthropic.claude-haiku-4-5-20251001-v1:0"
    }
  }

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}