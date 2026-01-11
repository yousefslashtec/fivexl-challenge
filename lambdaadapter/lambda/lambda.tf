terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
provider "aws" {
  region = var.aws_region
}

# Data sources to reference existing resources
data "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"
}

data "aws_ecr_repository" "lambda_repo" {
  name = "${var.project_name}-lambda"
}

# Lambda function with container image
resource "aws_lambda_function" "container_lambda" {
  function_name = var.lambda_function_name
  role         = data.aws_iam_role.lambda_role.arn
  package_type = "Image"
  image_uri    = "${data.aws_ecr_repository.lambda_repo.repository_url}:latest"
  timeout      = 30
  architectures = ["x86_64"]
}

# Lambda function URL
resource "aws_lambda_function_url" "lambda_url" {
  function_name      = aws_lambda_function.container_lambda.function_name
  authorization_type = "AWS_IAM"
}

# CloudFront Origin Access Control
resource "aws_cloudfront_origin_access_control" "lambda_oac" {
  name                              = "${var.project_name}-lambda-oac"
  description                       = "OAC for Lambda function URL"
  origin_access_control_origin_type = "lambda"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront distribution
resource "aws_cloudfront_distribution" "lambda_distribution" {
  origin {
    domain_name = replace(replace(aws_lambda_function_url.lambda_url.function_url, "https://", ""), "/", "")
    origin_id   = "lambda-origin"
    
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
    
    origin_access_control_id = aws_cloudfront_origin_access_control.lambda_oac.id
  }

  enabled = true

  default_cache_behavior {
    allowed_methods              = ["GET", "HEAD"]
    cached_methods               = ["GET", "HEAD"]
    target_origin_id             = "lambda-origin"
    compress                     = true
    viewer_protocol_policy       = "redirect-to-https"
    cache_policy_id              = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
  
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# Lambda resource policy for CloudFront OAC
resource "aws_lambda_permission" "cloudfront_invoke_url" {
  statement_id           = "AllowCloudFrontServicePrincipal"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.container_lambda.function_name
  principal              = "cloudfront.amazonaws.com"
  source_arn             = aws_cloudfront_distribution.lambda_distribution.arn

}

resource "aws_lambda_permission" "cloudfront_invoke_function" {
  statement_id  = "AllowCloudFrontServicePrincipal-new"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.container_lambda.function_name
  principal     = "cloudfront.amazonaws.com"
  source_arn    = aws_cloudfront_distribution.lambda_distribution.arn
}