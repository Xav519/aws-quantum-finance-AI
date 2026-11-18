# ==============================================================================
# modules/storage/main.tf
# ------------------------------------------------------------------------------
# PURPOSE
#   Where data lives: the DynamoDB jobs table and the S3 bucket for quantum results.
#
# DETAILS
#   DynamoDB table `<prefix>-jobs`
#     One item per optimization job (status, inputs, result) plus a daily quota
#     counter. Items delete themselves after 7 days (TTL).
#   S3 bucket `amazon-braket-<prefix>`
#     Amazon Braket writes each quantum task's raw measurements here. The name
#     prefix is required by Braket. Private, encrypted, TLS-only, auto-expiring.
# ==============================================================================

locals {
  prefix = "${var.project}-${var.environment}"

  # Amazon Braket requires the output bucket name to start with "amazon-braket-".
  # This is enforced at CreateQuantumTask time, regardless of IAM permissions.
  # 14 chars of prefix + at most 40 chars keeps us under the 63-char limit.
  braket_bucket_name = "amazon-braket-${substr(local.prefix, 0, 40)}"
}

# =============================================================================
# S3: raw Braket results
# =============================================================================
resource "aws_s3_bucket" "braket_results" {
  bucket        = local.braket_bucket_name
  force_destroy = true # Braket writes objects Terraform does not track
}

resource "aws_s3_bucket_public_access_block" "braket_results" {
  bucket                  = aws_s3_bucket.braket_results.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "braket_results" {
  bucket = aws_s3_bucket.braket_results.id
  rule {
    object_ownership = "BucketOwnerEnforced" # disables ACLs entirely
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "braket_results" {
  bucket = aws_s3_bucket.braket_results.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Results are only read once, by the completion handler. Keep them long enough
# to debug, then expire them so the bucket does not grow forever.
resource "aws_s3_bucket_lifecycle_configuration" "braket_results" {
  bucket = aws_s3_bucket.braket_results.id

  rule {
    id     = "expire-task-results"
    status = "Enabled"
    filter {}
    expiration {
      days = var.results_retention_days
    }
    # Clean up versions left from when versioning was enabled on this bucket
    noncurrent_version_expiration {
      noncurrent_days = 1
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

# Deny any request that is not over TLS.
resource "aws_s3_bucket_policy" "braket_results" {
  bucket     = aws_s3_bucket.braket_results.id
  depends_on = [aws_s3_bucket_public_access_block.braket_results]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource  = [aws_s3_bucket.braket_results.arn, "${aws_s3_bucket.braket_results.arn}/*"]
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }]
  })
}

# =============================================================================
# DynamoDB: job records
# =============================================================================
# Single-table, key-value access only (GetItem / PutItem / UpdateItem by job_id).
# The completion handler finds its job through the Braket task's `job_id` tag,
# so no secondary index is needed.
resource "aws_dynamodb_table" "jobs" {
  name         = "${local.prefix}-jobs"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "job_id"

  attribute {
    name = "job_id"
    type = "S"
  }

  # Items carry an epoch `expires_at`; DynamoDB deletes them automatically.
  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  server_side_encryption {
    enabled = true # AWS-managed KMS key
  }

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}
