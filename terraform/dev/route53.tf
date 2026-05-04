
# ============================================================
# route53.tf — Alias Record for ALB
# ============================================================

locals {
  # TODO: 도메인이 확정되면 아래 빈칸에 기입 (예: "api.dev.fin.com")
  domain_name = ""
  
  # 도메인이 소속된 루트 호스팅 영역 이름 (예: "fin.com")
  zone_name   = "your-domain.com" 
}

# 기존에 만들어진 Public Hosted Zone 정보를 AWS에서 동적으로 불러옴
data "aws_route53_zone" "dev" {
  name         = local.zone_name
  private_zone = false
}

resource "aws_route53_record" "dev" {
  # WHY: local.domain_name이 비어있으면 0이 되어 리소스를 생성하지 않음 (도메인 미정 방어)
  count = local.domain_name != "" ? 1 : 0

  zone_id = data.aws_route53_zone.dev.zone_id
  name    = local.domain_name
  type    = "A"

  alias {
    # 참조: alb.tf의 aws_lb.dev 값을 정확히 타겟팅
    name                   = aws_lb.dev.dns_name
    zone_id                = aws_lb.dev.zone_id
    evaluate_target_health = true
  }
}


