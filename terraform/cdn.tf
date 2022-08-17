module "cdn" {

  depends_on = [
    aws_acm_certificate.cert,
    aws_acm_certificate_validation.certvalidation,
  ]

  source = "terraform-aws-modules/cloudfront/aws"

  aliases = [
    "fatihkoc.net",
    "www.fatihkoc.net",
  ]

  comment             = "My awesome CloudFront"
  default_root_object = "index.html"
  enabled             = true
  is_ipv6_enabled     = true
  price_class         = "PriceClass_All"
  retain_on_delete    = false
  wait_for_deployment = false

  custom_error_response = [
    {
      "error_code"         = 404
      "response_code"      = 404
      "response_page_path" = "/404.html"
    },
    {
      "error_code"         = 403
      "response_code"      = 404
      "response_page_path" = "/404.html"
    }
  ]

  create_origin_access_identity = true
  origin_access_identities = {
    s3_bucket_one = "My awesome CloudFront can access"
  }

  origin = {
    s3_one = {
      domain_name = module.s3_bucket.s3_bucket_bucket_domain_name
      s3_origin_config = {
        origin_access_identity = "s3_bucket_one"
      }
    }
  }

  default_cache_behavior = {
    target_origin_id       = "s3_one"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]
    compress        = true
    query_string    = true

    function_association = {
      viewer-request = {
        function_arn = aws_cloudfront_function.redirect.arn
      }
    }
  }

  viewer_certificate = {
    acm_certificate_arn = aws_acm_certificate.cert.arn
    ssl_support_method  = "sni-only"
  }
}

resource "aws_cloudfront_function" "redirect" {
  depends_on = [
    module.cdn
  ]
  name = "redirect"
  runtime = "cloudfront-js-1.0"
  comment = "Redirects requests to index.html"
  publish = true
  code = file("scripts/redirect.js")
}