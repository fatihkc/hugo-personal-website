terraform {
  backend "s3" {
    bucket         = "fatihkocnet-terraform"
    key            = "terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "fatihkocnet-terraform-state"
  }
}