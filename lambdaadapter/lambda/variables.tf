variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "lambda-adapter"
}



variable "repo_name" {
  description = "CodeCommit repository name"
  type        = string
  default     = "lambda-adapter-repo"
}

variable "lambda_function_name" {
  description = "Lambda function name"
  type        = string
  default     = "lambda-adapter-function"
}