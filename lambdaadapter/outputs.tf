

output "codecommit_repo_url" {
  description = "CodeCommit repository clone URL"
  value       = aws_codecommit_repository.repo.clone_url_http
}

output "lambda_function_url" {
  description = "Lambda function URL (available after applying lambda.tf)"
  value       = "Will be available after applying lambda.tf"
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name (available after applying lambda.tf)"
  value       = "Will be available after applying lambda.tf"
}

output "cloudfront_url" {
  description = "CloudFront distribution URL (available after applying lambda.tf)"
  value       = "Will be available after applying lambda.tf"
}

output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.lambda_repo.repository_url
}

output "codepipeline_name" {
  description = "CodePipeline name"
  value       = aws_codepipeline.lambda_pipeline.name
}