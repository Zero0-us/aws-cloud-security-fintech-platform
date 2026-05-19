resource "aws_wafv2_web_acl" "dev" {
  name        = "fin-dev-waf"
  description = "Dev WAF in count mode for security testing"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "fin-dev-waf-main"
    sampled_requests_enabled   = true
  }

  rule {
    name     = "aws-managed-common-rules"
    priority = 1

    override_action {
      count {}
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

  rule {
    name     = "aws-managed-sql-injection"
    priority = 2

    override_action {
      count {}
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

resource "aws_wafv2_web_acl_association" "dev" {
  resource_arn = aws_lb.dev.arn
  web_acl_arn  = aws_wafv2_web_acl.dev.arn
}
