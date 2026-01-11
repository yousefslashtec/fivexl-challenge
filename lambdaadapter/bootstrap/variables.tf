variable "state_bucket_name" {
  description = "Base name for S3 bucket for Terraform state"
  type        = string
  default     = "terraform-state-lambda-adapter"
}