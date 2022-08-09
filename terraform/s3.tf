module "s3_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket = "fatihkocnet-hugo"
  acl    = "private"
  versioning = {
    enabled = true
  }
}