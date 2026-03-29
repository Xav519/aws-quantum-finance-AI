locals {
  prefix        = "${var.project}-${var.environment}"
  function_name = "${local.prefix}-classical"
  src_dir       = "${path.module}/src"
  zip_path      = "${path.module}/lambda_classical.zip"
}

# --- Build Process ---
# Automatically packages the 'src' directory into a .zip file.
# This data source runs every time 'terraform plan' or 'apply' is executed.
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = local.src_dir
  output_path = local.zip_path
}

resource "aws_lambda_function" "classical" {
  function_name    = local.function_name
  description      = "Brute-force assignment optimizer with Bedrock humanization"
  role             = var.lambda_role_arn
  # Standard Python handler (filename.function_name)
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  filename         = local.zip_path
  # RE-DEPLOYMENT TRIGGER:
  # This hash ensures that if you change a single line of Python code, 
  # Terraform detects the change and pushes the new zip to AWS.
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  # EXECUTION LIMITS:
  # 60s is plenty for classical permutations and a Bedrock API call.
  # 256MB is efficient for standard mathematical operations in Python.
  timeout          = 60
  memory_size      = 256

  # ENVIRONMENT VARIABLES:
  # These allow the Python code to interact with other AWS services without hardcoding names.
  environment {
    variables = {
      DYNAMODB_TABLE = var.dynamodb_table_name
      BEDROCK_MODEL  = "us.anthropic.claude-haiku-4-5-20251001-v1:0"
    }
  }

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}