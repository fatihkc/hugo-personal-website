resource "aws_route53_zone" "primary" {
  name = var.domain_name
}

# MX record for mail@fatihkoc.net
resource "aws_route53_record" "MX" {
  depends_on = [
    aws_route53_zone.primary
  ]
  zone_id = aws_route53_zone.primary.zone_id
  name    = var.domain_name
  type    = "MX"
  ttl     = 300
  records = ["10 mx.yandex.net."]
}

resource "aws_route53_record" "www" {
  depends_on = [
    module.cdn,
    aws_acm_certificate_validation.certvalidation
  ]
  zone_id = aws_route53_zone.primary.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  alias {
    name                   = module.cdn.cloudfront_distribution_domain_name
    zone_id                = module.cdn.cloudfront_distribution_hosted_zone_id
    evaluate_target_health = true
  }
}