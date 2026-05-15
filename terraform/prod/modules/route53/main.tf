resource "aws_route53_zone" "main" {
  name = var.env_name == "prod" ? var.base_domain : "${var.env_name}.${var.base_domain}"
}

resource "aws_route53_record" "alb_alias" {
  count = var.alb_dns_name == "" || var.alb_zone_id == "" ? 0 : 1

  zone_id = aws_route53_zone.main.zone_id
  name    = "api.${aws_route53_zone.main.name}"
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}
