locals {
  prefix        = "${var.project}-${var.environment}"
  function_name = "${local.prefix}-get-job"
}

# Packages src/ on every plan; the hash below triggers a redeploy on any code change.
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/build/lambda_get_job.zip"
  excludes    = ["**/__pycache__/**"]
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = var.log_retention_days
}

resource "aws_lambda_function" "get_job" {
  function_name    = local.function_name
  description      = "GET /jobs/{job_id}: job status and result from DynamoDB"
  role             = var.role_arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  architectures    = ["arm64"]
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  layers           = [var.layer_arn]
  timeout          = 10
  memory_size      = 128

  environment {
    variables = {
      DYNAMODB_TABLE = var.dynamodb_table_name
    }
  }

  depends_on = [aws_cloudwatch_log_group.this]

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}
