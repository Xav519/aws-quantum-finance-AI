
locals {
  prefix        = "${var.project}-${var.environment}"
  function_name = "${local.prefix}-orchestrator"
  src_dir       = "${path.module}/src"
  zip_path      = "${path.module}/lambda_orchestrator.zip"
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
resource "aws_lambda_function" "orchestrator" {
  function_name    = local.function_name
  description = "Routes optimization requests: classical (N=2..4) or quantum QAOA on Braket SV1 (N=5)"
  role             = var.lambda_role_arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  filename         = local.zip_path
  # RE-DEPLOYMENT TRIGGER:
  # This hash ensures that if you change a single line of Python code, 
  # Terraform detects the change and pushes the new zip to AWS.
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 90
  memory_size      = 256

  # ENVIRONMENT VARIABLES:
  # These allow the Python code to interact with other AWS services without hardcoding names.
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