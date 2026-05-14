# Hosted Zone 생성
resource "aws_route53_zone" "main" {
  name = var.env_name == "prod" ? var.base_domain : "${var.env_name}.${var.base_domain}"
}

# ALB로 트래픽을 보내는 A Alias 레코드
resource "aws_route53_record" "alb_alias" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "api.${aws_route53_zone.main.name}"
  type    = "A"

  alias {
    name                   = var.alb_dns_name # variables.tf에서 받은 값을 사용
    zone_id                = var.alb_zone_id  # variables.tf에서 받은 값을 사용
    evaluate_target_health = true
  }
}