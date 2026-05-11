resource "aws_wafv2_web_acl" "main" {
  name        = "fin-${var.env_name}-waf"
  description = "WAF for Fintech ${var.env_name} ALB"
  scope       = "REGIONAL"

  default_action { allow {} }

  # 1. 공통 공격 방어 룰셋
  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 1
    override_action { none {} }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "fin-${var.env_name}-waf-common"
      sampled_requests_enabled   = true
    }
  }

  # 2. SQL Injection 방어 룰셋
  rule {
    name     = "AWS-AWSManagedRulesSQLiRuleSet"
    priority = 2
    override_action { none {} }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "fin-${var.env_name}-waf-sqli"
      sampled_requests_enabled   = true
    }
  }

  # 3. 악성 입력값 방어 룰셋
  rule {
    name     = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
    priority = 3
    override_action { none {} }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "fin-${var.env_name}-waf-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "fin-${var.env_name}-waf-main"
    sampled_requests_enabled   = true
  }
}

resource "aws_wafv2_web_acl_association" "alb_association" {
  resource_arn = var.alb_arn # variables.tf에서 받은 값을 사용
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}