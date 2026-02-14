output "lambda_function_url" {
  description = "Lambda function URL"
  value       = aws_lambda_function_url.lambda_url.function_url
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.lambda_distribution.domain_name
}

output "cloudfront_url" {
  description = "CloudFront distribution URL"
  value       = "https://${aws_cloudfront_distribution.lambda_distribution.domain_name}"
}