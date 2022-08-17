provider "aws" {
  region = "eu-central-1"
}

# New provider for configuring Cloudfront
provider "aws" {
  alias  = "us-east"
  region = "us-east-1"
}