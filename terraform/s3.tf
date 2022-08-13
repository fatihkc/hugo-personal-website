module "s3_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket = "fatihkocnet-hugo"
  acl    = "public-read"
  versioning = {
    enabled = true
  }

  website = {
    index_document = "index.html"
    error_document = "404.html"
  }
}