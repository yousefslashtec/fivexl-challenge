terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
  backend "s3" {}
}

# S3 bucket for HTML files
resource "aws_s3_bucket" "html_files" {
  bucket = "${var.html_bucket_name}-${random_id.bucket_suffix.hex}"
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket_public_access_block" "html_files" {
  bucket = aws_s3_bucket.html_files.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "html_files" {
  bucket = aws_s3_bucket.html_files.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AmplifyReadAccess"
        Effect    = "Allow"
        Principal = {
          Service = "amplify.amazonaws.com"
        }
        Action   = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          aws_s3_bucket.html_files.arn,
          "${aws_s3_bucket.html_files.arn}/*"
        ]
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.html_files]
}

resource "aws_s3_bucket_website_configuration" "html_files" {
  bucket = aws_s3_bucket.html_files.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

# Lambda function to trigger Amplify deployment
resource "aws_iam_role" "amplify_trigger_lambda" {
  name = "amplify-trigger-lambda-role"

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

resource "aws_iam_role_policy" "amplify_trigger_lambda" {
  name = "amplify-trigger-policy"
  role = aws_iam_role.amplify_trigger_lambda.id

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
          "amplify:StartDeployment",
          "amplify:GetApp",
          "amplify:GetBranch"
        ]
        Resource = [
          aws_amplify_app.main.arn,
          "${aws_amplify_app.main.arn}/branches/main",
          "${aws_amplify_app.main.arn}/branches/main/*"
        ]
      }
    ]
  })
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/amplify-s3-trigger"
  retention_in_days = 14
}

resource "aws_lambda_function" "amplify_trigger" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "amplify-s3-trigger"
  role            = aws_iam_role.amplify_trigger_lambda.arn
  handler         = "lambda_function.lambda_handler"
  runtime         = "python3.9"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      AMPLIFY_APP_ID = aws_amplify_app.main.id
      BRANCH_NAME    = aws_amplify_branch.main.branch_name
      S3_BUCKET = aws_s3_bucket.html_files.id
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda_logs]
}

resource "aws_lambda_permission" "s3_invoke" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.amplify_trigger.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.html_files.arn
}

resource "aws_s3_bucket_notification" "html_files" {
  bucket = aws_s3_bucket.html_files.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.amplify_trigger.arn
    events              = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
  }

  depends_on = [aws_lambda_permission.s3_invoke]
}

# Create Lambda deployment package
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "amplify_trigger.zip"
  source {
    content = <<-EOT
import json
import boto3
import os

def lambda_handler(event, context):
    amplify = boto3.client('amplify', region_name=os.environ['AWS_REGION'])
    
    app_id = os.environ['AMPLIFY_APP_ID']
    branch_name = os.environ['BRANCH_NAME']
    s3_bucket = os.environ['S3_BUCKET']
    
    try:
        # For S3-based Amplify apps, use start_deployment
        response = amplify.start_deployment(
            appId=app_id,
            branchName=branch_name,
            sourceUrl=f's3://{s3_bucket}/',
            sourceUrlType='BUCKET_PREFIX'
        )
        
        deployment_id = response['jobSummary']['jobId']
        
        print(f'Deployment started: {deployment_id}')
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Amplify deployment triggered successfully',
                'deploymentId': deployment_id,
                'appId': app_id,
                'branchName': branch_name
            })
        }
    except Exception as e:
        print(f'Error: {str(e)}')
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }
    EOT
    filename = "lambda_function.py"
  }
}



# Amplify App
resource "aws_amplify_app" "main" {
  name = var.amplify_app_name

  # Custom rules for SPA routing
  custom_rule {
    source = "/<*>"
    status = "404"
    target = "/index.html"
  }

  # Environment variables
  environment_variables = {
    ENV = "production"
    S3_BUCKET = aws_s3_bucket.html_files.bucket
  }

  # IAM service role
  iam_service_role_arn = aws_iam_role.amplify_role.arn

  # Platform - WEB for static sites
  platform = "WEB"

  tags = {
    Environment = "production"
  }
}


# IAM role for Amplify service
resource "aws_iam_role" "amplify_role" {
  name = "${var.amplify_app_name}-amplify-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "amplify.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "amplify_s3_policy" {
  name = "${var.amplify_app_name}-amplify-s3-policy"
  role = aws_iam_role.amplify_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.html_files.arn,
          "${aws_s3_bucket.html_files.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_amplify_branch" "main" {
  app_id      = aws_amplify_app.main.id
  branch_name = "main"

  framework = "Web"
  stage     = "PRODUCTION"

  #  depends_on = [aws_s3_object.index_html]

}

# Upload sample HTML file to S3 , is triggered after all resources are created to trigger the deployment lambda
resource "aws_s3_object" "index_html" {
  bucket       = aws_s3_bucket.html_files.bucket
  key          = "index.html"
  source       = "index.html"
  content_type = "text/html"
  etag         = filemd5("index.html")

    depends_on = [aws_amplify_app.main,aws_lambda_function.amplify_trigger,aws_amplify_branch.main]
}

