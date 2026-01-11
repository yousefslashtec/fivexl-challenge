output "amplify_app_url" {
  description = "URL of the Amplify application"
  value       = "https://${aws_amplify_branch.main.branch_name}.${aws_amplify_app.main.default_domain}"
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for HTML files"
  value       = aws_s3_bucket.html_files.bucket
}

output "s3_website_url" {
  description = "S3 website endpoint"
  value       = aws_s3_bucket_website_configuration.html_files.website_endpoint
}