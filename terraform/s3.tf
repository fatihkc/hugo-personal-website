module "s3_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"
  bucket = "fatihkocnet-hugo"
  # Block all public access for security
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
  versioning = {
    enabled = true
  }

  website = {
    index_document = "index.html"
    error_document = "404.html"
    routing_rules = [{
      condition = {
        key_prefix_equals = "/"
      },
      redirect = {
        replace_key_prefix_with = "index.html"
      }
    }]
  }
}

# S3 bucket policy to allow only CloudFront OAI access
resource "aws_s3_bucket_policy" "cloudfront_access" {
  bucket = module.s3_bucket.s3_bucket_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          AWS = module.cdn.cloudfront_origin_access_identity_iam_arns[0]
        }
        Action   = "s3:GetObject"
        Resource = "${module.s3_bucket.s3_bucket_arn}/*"
      }
    ]
  })
}