terraform {
  backend "s3" {
    bucket         = "fatihkocnet-terraform"
    key            = "terraform.tfstate" # The path to the state file in your bucket.
    region         = "eu-central-1"
    dynamodb_table = "fatihkocnet-terraform-state" # Locking
  }
}