terraform {
  backend "s3" {
    bucket         = "terraformpipproject"
    key            = "terraform.tfstate"
    region         = "ap-southeast-2"
    encrypt        = true
    dynamodb_table = "terraform-lock"
  }
}
