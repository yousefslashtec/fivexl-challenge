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

# CodeCommit repository
resource "aws_codecommit_repository" "repo" {
  repository_name = var.repo_name
  description     = "Repository for Lambda container deployment"
}

# IAM role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_role.name
}

# ECR repository for Lambda container
resource "aws_ecr_repository" "lambda_repo" {
  name = "${var.project_name}-lambda"
}

# Lambda function with container image
# NOTE: This will be created in lambda.tf after first pipeline run
# resource "aws_lambda_function" "container_lambda" {
#   function_name = var.lambda_function_name
#   role         = aws_iam_role.lambda_role.arn
#   package_type = "Image"
#   image_uri    = "${aws_ecr_repository.lambda_repo.repository_url}:latest"
#   timeout      = 30
#   architectures = ["x86_64"]
# 
#   lifecycle {
#     ignore_changes = [image_uri]
#   }
# }

# Lambda function URL
# NOTE: This will be created in lambda.tf after first pipeline run
# resource "aws_lambda_function_url" "lambda_url" {
#   function_name      = aws_lambda_function.container_lambda.function_name
#   authorization_type = "AWS_IAM"
# }

# CloudFront Origin Access Control
# NOTE: This will be created in lambda.tf after first pipeline run
# resource "aws_cloudfront_origin_access_control" "lambda_oac" {
#   name                              = "${var.project_name}-lambda-oac"
#   description                       = "OAC for Lambda function URL"
#   origin_access_control_origin_type = "lambda"
#   signing_behavior                  = "always"
#   signing_protocol                  = "sigv4"
# }

# CloudFront distribution
# NOTE: This will be created in lambda.tf after first pipeline run
# resource "aws_cloudfront_distribution" "lambda_distribution" {
#   origin {
#     domain_name = replace(aws_lambda_function_url.lambda_url.function_url, "https://", "")
#     origin_id   = "lambda-origin"
#     
#     custom_origin_config {
#       http_port              = 80
#       https_port             = 443
#       origin_protocol_policy = "http-only"
#       origin_ssl_protocols   = ["TLSv1.2"]
#     }
#     
#     origin_access_control_id = aws_cloudfront_origin_access_control.lambda_oac.id
#   }
# 
#   enabled = true
# 
#   default_cache_behavior {
#     allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
#     cached_methods         = ["GET", "HEAD"]
#     target_origin_id       = "lambda-origin"
#     compress               = true
#     viewer_protocol_policy = "redirect-to-https"
# 
#     forwarded_values {
#       query_string = true
#       headers      = ["*"]
#       cookies {
#         forward = "all"
#       }
#     }
# 
#     min_ttl     = 0
#     default_ttl = 0
#     max_ttl     = 0
#   }
# 
#   restrictions {
#     geo_restriction {
#       restriction_type = "none"
#     }
#   }
# 
#   viewer_certificate {
#     cloudfront_default_certificate = true
#   }
# }

# Update Lambda resource policy for CloudFront OAC
# NOTE: This will be created in lambda.tf after first pipeline run
# resource "aws_lambda_permission" "cloudfront_invoke" {
#   statement_id           = "AllowCloudFrontInvoke"
#   action                 = "lambda:InvokeFunctionUrl"
#   function_name          = aws_lambda_function.container_lambda.function_name
#   principal              = "cloudfront.amazonaws.com"
#   source_arn             = aws_cloudfront_distribution.lambda_distribution.arn
#   function_url_auth_type = "AWS_IAM"
# }

# IAM role for CodePipeline
resource "aws_iam_role" "codepipeline_role" {
  name = "${var.project_name}-codepipeline-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "${var.project_name}-codepipeline-policy"
  role = aws_iam_role.codepipeline_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketVersioning",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject"
        ]
        Resource = [
          aws_s3_bucket.codepipeline_artifacts.arn,
          "${aws_s3_bucket.codepipeline_artifacts.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "codecommit:*"

        ]
        Resource = aws_codecommit_repository.repo.arn
      },
      {
        Effect = "Allow"
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild"
        ]
        Resource = aws_codebuild_project.lambda_build.arn
      }
    ]
  })
}

# S3 bucket for CodePipeline artifacts
resource "aws_s3_bucket" "codepipeline_artifacts" {
  bucket = "${var.project_name}-codepipeline-artifacts"
}

# IAM role for CodeBuild
resource "aws_iam_role" "codebuild_role" {
  name = "${var.project_name}-codebuild-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "codebuild_policy" {
  name = "${var.project_name}-codebuild-policy"
  role = aws_iam_role.codebuild_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject"
        ]
        Resource = [
          aws_s3_bucket.codepipeline_artifacts.arn,
          "${aws_s3_bucket.codepipeline_artifacts.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:GetAuthorizationToken",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:UpdateFunctionCode"
        ]
        Resource = "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:${var.lambda_function_name}"
      }
    ]
  })
}

# CodeBuild project
resource "aws_codebuild_project" "lambda_build" {
  name         = "${var.project_name}-build"
  service_role = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                      = "aws/codebuild/amazonlinux2-x86_64-standard:3.0"
    type                       = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode            = true

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }
    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = data.aws_caller_identity.current.account_id
    }
    environment_variable {
      name  = "IMAGE_REPO_NAME"
      value = aws_ecr_repository.lambda_repo.name
    }
    environment_variable {
      name  = "LAMBDA_FUNCTION_NAME"
      value = var.lambda_function_name
    }
  }

  source {
    type = "CODEPIPELINE"
    buildspec = "buildspec.yml"
  }
}

# CodePipeline
resource "aws_codepipeline" "lambda_pipeline" {
  name     = "${var.project_name}-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.codepipeline_artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        RepositoryName = aws_codecommit_repository.repo.repository_name
        BranchName     = "main"
      }
    }
  }

  stage {
    name = "Build"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.lambda_build.name
      }
    }
  }
}

data "aws_caller_identity" "current" {}