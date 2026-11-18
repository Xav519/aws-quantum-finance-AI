# =============================================================================
# IAM: one execution role per Lambda (least privilege)
# -----------------------------------------------------------------------------
#   orchestrator : write job records, invoke the classical + braket functions
#   classical    : write job records, call Bedrock
#   braket       : read/update job records, Braket tasks, results bucket, Bedrock
#   get_job      : read job records only
# Every statement is scoped to a concrete ARN except the Braket task actions,
# which do not support resource-level permissions for task creation.
# =============================================================================

data "aws_caller_identity" "current" {}

locals {
  prefix     = "${var.project}-${var.environment}"
  account_id = data.aws_caller_identity.current.account_id
  region     = var.aws_region

  function_names = {
    orchestrator = "${local.prefix}-orchestrator"
    classical    = "${local.prefix}-classical"
    braket       = "${local.prefix}-braket"
    get_job      = "${local.prefix}-get-job"
  }

  # Cross-region inference profile IDs look like "us.anthropic.claude-...";
  # the underlying foundation-model ID drops the geography prefix.
  foundation_model_id = replace(var.bedrock_model_id, "/^(us|eu|apac|global)\\./", "")

  bedrock_resources = [
    "arn:aws:bedrock:${local.region}:${local.account_id}:inference-profile/${var.bedrock_model_id}",
    # An inference profile routes to the model in several regions of the geography.
    "arn:aws:bedrock:*::foundation-model/${local.foundation_model_id}",
  ]

  assume_lambda = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# Logs: each function may only write to its own, pre-created log group.
data "aws_iam_policy_document" "logs" {
  for_each = local.function_names

  statement {
    sid       = "WriteOwnLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/${each.value}:*"]
  }
}

# --- Orchestrator -------------------------------------------------------------
resource "aws_iam_role" "orchestrator" {
  name               = "${local.prefix}-orchestrator-role"
  assume_role_policy = local.assume_lambda
}

data "aws_iam_policy_document" "orchestrator" {
  source_policy_documents = [data.aws_iam_policy_document.logs["orchestrator"].json]

  statement {
    sid       = "JobRecords"
    actions   = ["dynamodb:PutItem", "dynamodb:UpdateItem"]
    resources = [var.jobs_table_arn]
  }

  statement {
    sid     = "InvokeSolvers"
    actions = ["lambda:InvokeFunction"]
    resources = [
      "arn:aws:lambda:${local.region}:${local.account_id}:function:${local.function_names.classical}",
      "arn:aws:lambda:${local.region}:${local.account_id}:function:${local.function_names.braket}",
    ]
  }
}

resource "aws_iam_role_policy" "orchestrator" {
  name   = "${local.prefix}-orchestrator-policy"
  role   = aws_iam_role.orchestrator.id
  policy = data.aws_iam_policy_document.orchestrator.json
}

# --- Classical solver ---------------------------------------------------------
resource "aws_iam_role" "classical" {
  name               = "${local.prefix}-classical-role"
  assume_role_policy = local.assume_lambda
}

data "aws_iam_policy_document" "classical" {
  source_policy_documents = [data.aws_iam_policy_document.logs["classical"].json]

  statement {
    sid       = "JobRecords"
    actions   = ["dynamodb:PutItem"]
    resources = [var.jobs_table_arn]
  }

  statement {
    sid       = "Narrative"
    actions   = ["bedrock:InvokeModel"]
    resources = local.bedrock_resources
  }
}

resource "aws_iam_role_policy" "classical" {
  name   = "${local.prefix}-classical-policy"
  role   = aws_iam_role.classical.id
  policy = data.aws_iam_policy_document.classical.json
}

# --- Braket (quantum) ---------------------------------------------------------
resource "aws_iam_role" "braket" {
  name               = "${local.prefix}-braket-role"
  assume_role_policy = local.assume_lambda
}

data "aws_iam_policy_document" "braket" {
  source_policy_documents = [data.aws_iam_policy_document.logs["braket"].json]

  statement {
    sid       = "JobRecords"
    actions   = ["dynamodb:GetItem", "dynamodb:UpdateItem"]
    resources = [var.jobs_table_arn]
  }

  statement {
    sid       = "QuantumTasks"
    actions   = ["braket:CreateQuantumTask", "braket:GetQuantumTask", "braket:TagResource"]
    resources = ["*"]
  }

  statement {
    sid       = "TaskResults"
    actions   = ["s3:PutObject", "s3:GetObject"]
    resources = ["${var.results_bucket_arn}/*"]
  }

  statement {
    sid       = "Narrative"
    actions   = ["bedrock:InvokeModel"]
    resources = local.bedrock_resources
  }
}

resource "aws_iam_role_policy" "braket" {
  name   = "${local.prefix}-braket-policy"
  role   = aws_iam_role.braket.id
  policy = data.aws_iam_policy_document.braket.json
}

# --- Get job ------------------------------------------------------------------
resource "aws_iam_role" "get_job" {
  name               = "${local.prefix}-get-job-role"
  assume_role_policy = local.assume_lambda
}

data "aws_iam_policy_document" "get_job" {
  source_policy_documents = [data.aws_iam_policy_document.logs["get_job"].json]

  statement {
    sid       = "ReadJobRecords"
    actions   = ["dynamodb:GetItem"]
    resources = [var.jobs_table_arn]
  }
}

resource "aws_iam_role_policy" "get_job" {
  name   = "${local.prefix}-get-job-policy"
  role   = aws_iam_role.get_job.id
  policy = data.aws_iam_policy_document.get_job.json
}
