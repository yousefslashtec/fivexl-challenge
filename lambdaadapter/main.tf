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
resource "aws_lambda_function" "container_lambda" {
  function_name = var.lambda_function_name
  role         = aws_iam_role.lambda_role.arn
  package_type = "Image"
  image_uri    = "${aws_ecr_repository.lambda_repo.repository_url}:latest"
  timeout      = 30
  architectures = ["x86_64"]
  depends_on    = [aws_codebuild_project.lambda_build, null_resource.wait_for_image]

  lifecycle {
    ignore_changes = [image_uri]
  }
  publish = true
}

# Lambda alias for CodeDeploy
resource "aws_lambda_alias" "live" {
  name             = "live"
  function_name    = aws_lambda_function.container_lambda.function_name
  function_version = aws_lambda_function.container_lambda.version
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
  statement_id       = "AllowCloudFrontServicePrincipal"
  action             = "lambda:InvokeFunctionUrl"
  function_name      = aws_lambda_function.container_lambda.function_name
  principal          = "cloudfront.amazonaws.com"
  source_arn         = aws_cloudfront_distribution.lambda_distribution.arn
}

resource "aws_lambda_permission" "cloudfront_invoke_function" {
  statement_id  = "AllowCloudFrontServicePrincipal-new"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.container_lambda.function_name
  principal     = "cloudfront.amazonaws.com"
  source_arn    = aws_cloudfront_distribution.lambda_distribution.arn
}

# IAM role for CodeDeploy
resource "aws_iam_role" "codedeploy_role" {
  name = "${var.project_name}-codedeploy-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codedeploy.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "codedeploy_lambda" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRoleForLambda"
  role       = aws_iam_role.codedeploy_role.name
}

resource "aws_iam_role_policy" "codedeploy_s3" {
  name = "${var.project_name}-codedeploy-s3-policy"
  role = aws_iam_role.codedeploy_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = "${aws_s3_bucket.codepipeline_artifacts.arn}/*"
      }
    ]
  })
}

# CodeDeploy application
resource "aws_codedeploy_app" "lambda_app" {
  compute_platform = "Lambda"
  name             = "${var.project_name}-lambda-app"
}

# CodeDeploy deployment group
resource "aws_codedeploy_deployment_group" "lambda_deployment_group" {
  app_name              = aws_codedeploy_app.lambda_app.name
  deployment_group_name = "${var.project_name}-lambda-deployment-group"
  service_role_arn      = aws_iam_role.codedeploy_role.arn

  deployment_config_name = "CodeDeployDefault.LambdaAllAtOnce"

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }
}

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
      },
      {
        Effect = "Allow"
        Action = [
          "codedeploy:CreateDeployment",
          "codedeploy:GetApplication",
          "codedeploy:GetApplicationRevision",
          "codedeploy:GetDeployment",
          "codedeploy:GetDeploymentConfig",
          "codedeploy:RegisterApplicationRevision"
        ]
        Resource = "*"
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
          "lambda:PublishVersion",
          "lambda:UpdateFunctionCode",
          "lambda:GetAlias",
          "lambda:GetFunction"
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
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.lambda_build.name
      }
    }
  }

  stage {
    name = "Deploy"
    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      input_artifacts = ["build_output"]
      version         = "1"

      configuration = {
        ApplicationName     = aws_codedeploy_app.lambda_app.name
        DeploymentGroupName = aws_codedeploy_deployment_group.lambda_deployment_group.deployment_group_name
      }
    }
  }
}

data "aws_caller_identity" "current" {}

# Push files to CodeCommit repository
resource "null_resource" "push_to_codecommit" {
  depends_on = [aws_codecommit_repository.repo]

  provisioner "local-exec" {
    command = <<-EOT
      sudo -H apt update
      sudo -H apt install -y pipx
      sudo -H pipx ensurepath
      sudo -H pipx install git-remote-codecommit
      git clone codecommit::${var.aws_region}://${aws_codecommit_repository.repo.repository_name}
      cd ${aws_codecommit_repository.repo.repository_name}
      cp ../buildspec.yml ../Dockerfile ../index.html  .
      git add .
      git commit -m "Add container files"
      git branch -M main
      git push origin main
      cd ..
      rm -rf ${aws_codecommit_repository.repo.repository_name}
    EOT
  }

  triggers = {
    repo_name = aws_codecommit_repository.repo.repository_name
  }
}

# Wait for pipeline to complete and image to be available
resource "null_resource" "wait_for_image" {
  depends_on = [null_resource.push_to_codecommit]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for pipeline to build image..."
      sleep 300
      for i in {1..240}; do
        if aws ecr describe-images --repository-name ${aws_ecr_repository.lambda_repo.name} --image-ids imageTag=latest --region ${var.aws_region} 2>/dev/null; then
          echo "Image found in ECR"
          exit 0
        fi
        echo "Waiting for image... ($i/60)"
        sleep 10
      done
      echo "Timeout waiting for image"
      exit 1
    EOT
  }
}