# --- Configuration Locals ---
locals {
    # Unique naming prefix ex: myproject-dev
  prefix = "${var.project}-${var.environment}"
}

# --- Standard Lambda Role ---
# This defines the "Identity" that the Lambda function will assume.
resource "aws_iam_role" "lambda_role" {
  name = "${local.prefix}-lambda-role"

# Trust Policy: Allows the AWS Lambda service itself to use this role.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# Permissions for the Standard Lambda
resource "aws_iam_role_policy" "lambda_policy" {
  name = "${local.prefix}-lambda-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
    # Logging: Allows the function to write logs to CloudWatch.
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      },
    # Database: CRU(D) operations on DynamoDB tables matching the prefix.
      {
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:UpdateItem"]
        Resource = "arn:aws:dynamodb:*:*:table/${local.prefix}-*"
      },
    # Inter-connectivity: Allows this Lambda to trigger other Lambdas.
      {
        Effect   = "Allow"
        Action   = ["lambda:InvokeFunction"]
        Resource = "arn:aws:lambda:*:*:function:${local.prefix}-*"
      },
    # AI/ML: Specifically allows calling the Claude 3 Haiku model via Bedrock.
      {
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel"]
        Resource = "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-haiku-4-5-20251001-v1:0"
      }
    ]
  })
}


# --- Braket Lambda Role (Quantum Computing) ---
resource "aws_iam_role" "lambda_braket_role" {
  name = "${local.prefix}-lambda-braket-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# Specific Permissions for Quantum Workflows
resource "aws_iam_role_policy" "lambda_braket_policy" {
  name = "${local.prefix}-lambda-braket-policy"
  role = aws_iam_role.lambda_braket_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
    # Logging: Allows the function to write logs to CloudWatch
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      },
    # Database access
      {
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:UpdateItem"]
        Resource = "arn:aws:dynamodb:*:*:table/${local.prefix}-*"
      },
    # Quantum Tasks: Permission to create and manage Amazon Braket tasks.
      {
        Effect   = "Allow"
        Action   = ["braket:CreateQuantumTask", "braket:GetQuantumTask", "braket:CancelQuantumTask", "braket:SearchQuantumTasks"]
        Resource = "*"
      },
    # Storage: Read/Write access to S3 buckets for quantum result data.
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:GetObject"]
        Resource = "arn:aws:s3:::${local.prefix}-*/*"
      }
    ]
  })
}
