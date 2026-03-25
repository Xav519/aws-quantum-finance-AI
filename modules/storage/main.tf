locals {
    # Standard prefix for all resources to ensure uniqueness and easy identification
  prefix = "${var.project}-${var.environment}"
}

# - S3 Bucket: Raw Braket Results -
# This is where the output files from quantum computing tasks will live.
resource "aws_s3_bucket" "braket_results" {
  bucket = "${local.prefix}-braket-results"
}

# Enables Versioning: Allows you to recover previous versions of an object.
resource "aws_s3_bucket_versioning" "braket_results" {
  bucket = aws_s3_bucket.braket_results.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Server-Side Encryption: Ensures data is encrypted before being saved to disk.
resource "aws_s3_bucket_server_side_encryption_configuration" "braket_results" {
  bucket = aws_s3_bucket.braket_results.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Security lockdown (to be sure): Explicitly blocks all public access to the bucket.
resource "aws_s3_bucket_public_access_block" "braket_results" {
  bucket                  = aws_s3_bucket.braket_results.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB: Job Status Table
resource "aws_dynamodb_table" "jobs" {
  name         = "${local.prefix}-jobs"
  # On-demand pricing: You only pay for the reads/writes you actually use.
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "job_id" # Primary Key: Every job must have a unique String (S) ID.

  attribute {
    name = "job_id"
    type = "S"
  }

# Automatic Cleanup: Deletes the item when the 'expires_at' Unix timestamp is reached.
  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }
}
