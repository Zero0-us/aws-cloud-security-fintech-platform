variable "dev_domain_name" {
  description = "Optional dev DNS name, for example dev.example.com. Leave empty to use the ALB DNS directly."
  type        = string
  default     = ""
}

variable "dev_zone_name" {
  description = "Optional public Route53 hosted zone name, for example example.com."
  type        = string
  default     = ""
}

locals {
  create_dev_dns = var.dev_domain_name != "" && var.dev_zone_name != ""
}

data "aws_route53_zone" "dev" {
  count        = local.create_dev_dns ? 1 : 0
  name         = var.dev_zone_name
  private_zone = false
}

resource "aws_route53_record" "dev" {
  count = local.create_dev_dns ? 1 : 0

  zone_id = data.aws_route53_zone.dev[0].zone_id
  name    = var.dev_domain_name
  type    = "A"

  alias {
    name                   = aws_lb.dev.dns_name
    zone_id                = aws_lb.dev.zone_id
    evaluate_target_health = true
  }
}
