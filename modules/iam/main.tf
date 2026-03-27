# --- Configuration Locals ---
locals {
  prefix = "${var.project}-${var.environment}"
}

# --- Standard Lambda Role ---
resource "aws_iam_role" "lambda_role" {
  name = "${local.prefix}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "${local.prefix}-lambda-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:UpdateItem", "dynamodb:Scan", "dynamodb:Query"]
        Resource = [
          "arn:aws:dynamodb:*:*:table/${local.prefix}-*",
          "arn:aws:dynamodb:*:*:table/${local.prefix}-*/index/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["lambda:InvokeFunction"]
        Resource = "arn:aws:lambda:*:*:function:${local.prefix}-*"
      },
      # FIX: use cross-region inference profile ARN (required for Claude 4.x models)
      # The old foundation-model ARN only works for Claude 2/3; Claude 4.x requires
      # on-demand throughput via an inference profile.
      {
        Effect = "Allow"
        Action = ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"]
        Resource = [
          "arn:aws:bedrock:*::foundation-model/anthropic.claude-haiku-4-5-20251001-v1:0",
          "arn:aws:bedrock:us-east-1:*:inference-profile/us.anthropic.claude-haiku-4-5-20251001-v1:0"
        ]
      },

      # Added permissions for AWS Marketplace subscription management, which is required to access certain Bedrock models. This allows the Lambda function to check subscription status and manage subscriptions as needed.
      {
        Effect   = "Allow"
        Action   = ["aws-marketplace:ViewSubscriptions", "aws-marketplace:Subscribe", "aws-marketplace:Unsubscribe"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"]
        Resource = [
          "arn:aws:bedrock:*::foundation-model/anthropic.claude-haiku-4-5-20251001-v1:0",
          "arn:aws:bedrock:us-east-1:*:inference-profile/us.anthropic.claude-haiku-4-5-20251001-v1:0"
        ]
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

resource "aws_iam_role_policy" "lambda_braket_policy" {
  name = "${local.prefix}-lambda-braket-policy"
  role = aws_iam_role.lambda_braket_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:UpdateItem", "dynamodb:Scan", "dynamodb:Query"]
        Resource = [
          "arn:aws:dynamodb:*:*:table/${local.prefix}-*",
          "arn:aws:dynamodb:*:*:table/${local.prefix}-*/index/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["braket:CreateQuantumTask", "braket:GetQuantumTask", "braket:CancelQuantumTask", "braket:SearchQuantumTasks"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:GetObject"]
        Resource = [
          "arn:aws:s3:::amazon-braket-${local.prefix}/*",
          "arn:aws:s3:::amazon-braket-*/*"
        ]
      },
      # FIX: braket role was missing Bedrock permission entirely — added here
      {
        Effect = "Allow"
        Action = ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"]
        Resource = [
          "arn:aws:bedrock:*::foundation-model/anthropic.claude-haiku-4-5-20251001-v1:0",
          "arn:aws:bedrock:us-east-1:*:inference-profile/us.anthropic.claude-haiku-4-5-20251001-v1:0"
        ]
      },

      # Added permissions for AWS Marketplace subscription management, which is required to access certain Bedrock models. This allows the Lambda function to check subscription status and manage subscriptions as needed.
      {
        Effect   = "Allow"
        Action   = ["aws-marketplace:ViewSubscriptions", "aws-marketplace:Subscribe", "aws-marketplace:Unsubscribe"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"]
        Resource = [
          "arn:aws:bedrock:*::foundation-model/anthropic.claude-haiku-4-5-20251001-v1:0",
          "arn:aws:bedrock:us-east-1:*:inference-profile/us.anthropic.claude-haiku-4-5-20251001-v1:0"
        ]
      }
    ]
  })
}
