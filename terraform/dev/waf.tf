# ============================================================
# waf.tf — WAFv2 Web ACL & ALB Association
# ============================================================

resource "aws_wafv2_web_acl" "dev" {
  name        = "fin-dev-waf"
  description = "Dev WAF with Count mode for Security Testing"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "fin-dev-waf-main"
    sampled_requests_enabled   = true
  }

  # --------------------------------------------------------------
  # Rule 1: Common Rule Set
  # --------------------------------------------------------------
  rule {
    name     = "aws-managed-common-rules"
    priority = 1

    override_action {
      count {} # WHY: 개발 환경 차단 방지 및 모니터링 목적
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "fin-dev-waf-common"
      sampled_requests_enabled   = true
    }
  }

  # --------------------------------------------------------------
  # Rule 2: SQL Injection Rule Set
  # --------------------------------------------------------------
  rule {
    name     = "aws-managed-sql-injection"
    priority = 2

    override_action {
      count {} # WHY: 보안팀 SQLi 시뮬레이션 탐지율 측정용
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "fin-dev-waf-sqli"
      sampled_requests_enabled   = true
    }
  }

  # --------------------------------------------------------------
  # Rule 3: Known Bad Inputs Rule Set
  # --------------------------------------------------------------
  rule {
    name     = "aws-managed-known-bad-inputs"
    priority = 3

    override_action {
      count {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "fin-dev-waf-bad-inputs"
      sampled_requests_enabled   = true
    }
  }
}

# --------------------------------------------------------------
# WAF - ALB Association
# --------------------------------------------------------------
resource "aws_wafv2_web_acl_association" "dev" {
  # 참조: alb.tf에 있는 aws_lb.dev의 ARN을 다이렉트로 가져옴
  resource_arn = aws_lb.dev.arn
  web_acl_arn  = aws_wafv2_web_acl.dev.arn
}