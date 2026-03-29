locals {
  prefix        = "${var.project}-${var.environment}"
  function_name = "${local.prefix}-get-job"
  src_dir       = "${path.module}/src"
  zip_path      = "${path.module}/lambda_get_job.zip"
}

# --- Build Process ---
# Automatically packages the 'src' directory into a .zip file.
# This data source runs every time 'terraform plan' or 'apply' is executed.
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = local.src_dir
  output_path = local.zip_path
}

# --- Lambda Function Resource ---
resource "aws_lambda_function" "get_job" {
  function_name    = local.function_name
  description      = "Returns job status and result from DynamoDB for async quantum flow"
  role             = var.lambda_role_arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  filename         = local.zip_path
  # RE-DEPLOYMENT TRIGGER:
  # This hash ensures that if you change a single line of Python code, 
  # Terraform detects the change and pushes the new zip to AWS.
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 15
  memory_size      = 128

  # ENVIRONMENT VARIABLES:
  # These allow the Python code to interact with other AWS services without hardcoding names.
  environment {
    variables = {
      DYNAMODB_TABLE = var.dynamodb_table_name
    }
  }

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}