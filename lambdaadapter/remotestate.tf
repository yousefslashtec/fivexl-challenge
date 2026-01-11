data "terraform_remote_state" "bootstrap" {
  backend = "local"
  
  config = {
    path = "./bootstrap/terraform.tfstate"
  }
}

terraform {
  backend "s3" {
    key = "main/terraform.tfstate"
  }
}