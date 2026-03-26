output "demo_url" {
  description = "Public URL of the demo frontend"
  value       = "http://${aws_s3_bucket.frontend.bucket}.s3-website-us-east-1.amazonaws.com"
}