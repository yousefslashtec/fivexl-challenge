variable "html_bucket_name" {
  description = "Base name for S3 bucket to store HTML files"
  type        = string
  default     = "amplify-html-files"
}

variable "amplify_app_name" {
  description = "Name of the Amplify application"
  type        = string
  default     = "amplify-s3-app"
}