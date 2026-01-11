data "terraform_remote_state" "bootstrap" {
  backend = "local"
  
  config = {
    path = "../bootstrap/terraform.tfstate"
  }
}

data "terraform_remote_state" "main" {
  backend = "s3"
  
  config = {
    bucket = data.terraform_remote_state.bootstrap.outputs.s3_state_bucket
    key    = "main/terraform.tfstate"
    region = "us-east-2"
  }
}

terraform {
  backend "s3" {
    key = "lambda/terraform.tfstate"
  }
}