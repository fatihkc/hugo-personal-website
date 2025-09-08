module "s3_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"
  bucket = "fatihkocnet-hugo"
  versioning = {
    enabled = true
  }

  # Block all public access
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  # Bucket policy to allow only CloudFront OAI access
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontServicePrincipal"
        Effect    = "Allow"
        Principal = {
          AWS = "arn:aws:iam::cloudfront:user/CloudFront Origin Access Identity ${module.cdn.cloudfront_origin_access_identity_ids.s3_bucket_one}"
        }
        Action   = "s3:GetObject"
        Resource = "${module.s3_bucket.s3_bucket_arn}/*"
      }
    ]
  })

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