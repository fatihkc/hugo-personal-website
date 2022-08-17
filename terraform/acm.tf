resource "aws_acm_certificate" "cert" {
  provider                  = aws.us-east # CloudFront only supports certificates in us-east-1
  domain_name               = var.domain_name
  subject_alternative_names = ["*.fatihkoc.net"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_route53_zone.primary]
}

# Create a DNS record to prove that we _own_ the domain we're requesting a certificate for
resource "aws_route53_record" "certvalidation" {

  provider = aws.us-east # Cloudfront only supports us-east-1

  for_each = {
    for d in aws_acm_certificate.cert.domain_validation_options : d.domain_name => {
      name   = d.resource_record_name
      record = d.resource_record_value
      type   = d.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.primary.zone_id
}

# Validate the certificate
resource "aws_acm_certificate_validation" "certvalidation" {
  provider                = aws.us-east # Cloudfront only supports us-east-1
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for r in aws_route53_record.certvalidation : r.fqdn]
}

# Create Route53 record for the domain
resource "aws_route53_record" "websiteurl" {

  depends_on = [
    module.cdn
  ]

  name    = var.domain_name
  zone_id = aws_route53_zone.primary.zone_id
  type    = "A"

  alias {
    name                   = module.cdn.cloudfront_distribution_domain_name
    zone_id                = module.cdn.cloudfront_distribution_hosted_zone_id
    evaluate_target_health = true
  }
}