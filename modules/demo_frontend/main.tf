locals {
  prefix = "${var.project}-${var.environment}"
}

# --- S3 Bucket ---
# The primary storage container for your website files
resource "aws_s3_bucket" "frontend" {
  bucket        = "${local.prefix}-demo-frontend"
  force_destroy = true # Allows Terraform to delete the bucket even if it contains files
  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

# --- Static Website Configuration ---
# Configures the bucket to act as a web server, identifying the entry point file
resource "aws_s3_bucket_website_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  index_document { suffix = "index.html" }
}

# --- Public Access Control ---
# This block EXPLICITLY disables the default S3 security protections that block public access.
# Required because we want the general public to be able to view the website.
resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket                  = aws_s3_bucket.frontend.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# --- Bucket Policy ---
# Grants "Read Only" permissions to the entire internet so anyone can load the website files.
resource "aws_s3_bucket_policy" "frontend" {
  bucket     = aws_s3_bucket.frontend.id
  # Ensures the Public Access Block is removed BEFORE applying this policy to avoid a conflict error
  depends_on = [aws_s3_bucket_public_access_block.frontend]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "PublicRead"
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject" # Grants permission to read objects in the bucket
      Resource  = "${aws_s3_bucket.frontend.arn}/*" # Applies to all files inside the bucket
    }]
  })
}

# --- Website Entry Point (index.html) ---
# Uploads the main HTML file. It uses 'templatefile' to inject the API URL dynamically,
# allowing the frontend to know exactly which backend to talk to.
resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.frontend.id
  key          = "index.html"
  content_type = "text/html" # Crucial so the browser renders it as a page rather than downloading it

  content = templatefile("${path.module}/index.html.tpl", {
    api_url = var.api_url
  })
}