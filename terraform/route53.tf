resource "aws_route53_zone" "primary" {
  name = var.domain_name
}

# MX record for mail@fatihkoc.net
resource "aws_route53_record" "MX" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = var.domain_name
  type    = "MX"
  ttl     = 300
  records = ["10 mx.yandex.net."]
}

resource "aws_route53_record" "CNAME" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "www.fatihkoc.net"
  type    = "CNAME"
  ttl     = 300
  records = ["fatihkoc.net"]
}