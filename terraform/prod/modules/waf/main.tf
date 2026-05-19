resource "aws_wafv2_web_acl" "main" {
  name        = "fin-${var.env_name}-waf"
  description = "WAF for Fintech ${var.env_name} ingress ALB"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

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

  rule {
    name     = "AWS-AWSManagedRulesSQLiRuleSet"
    priority = 2

    override_action {
      none {}
    }

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

  rule {
    name     = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
    priority = 3

    override_action {
      none {}
    }

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
  count        = var.alb_arn == null ? 0 : 1
  resource_arn = var.alb_arn
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}

# ============================================================
# WAF 로그 → CloudWatch Logs
# ============================================================
# WAF는 S3 직접 전송 불가. CloudWatch Logs로 보낸 뒤
# SOC Lambda가 수집해서 SOC S3로 export하는 구조.
# log group 이름은 반드시 "aws-waf-logs-" 로 시작해야 함 (AWS 제약).
# ============================================================

resource "aws_cloudwatch_log_group" "waf" {
  name              = "aws-waf-logs-fin-${var.env_name}-waf"
  retention_in_days = var.log_retention_days

  tags = {
    Name      = "aws-waf-logs-fin-${var.env_name}-waf"
    ManagedBy = "Terraform"
  }
}

resource "aws_cloudwatch_log_resource_policy" "waf" {
  policy_name = "fin-${var.env_name}-waf-log-policy"

  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.waf.arn}:*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

data "aws_caller_identity" "current" {}

resource "aws_wafv2_web_acl_logging_configuration" "main" {
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]
  resource_arn            = aws_wafv2_web_acl.main.arn

  depends_on = [aws_cloudwatch_log_resource_policy.waf]
}

# ============================================================
# WAF 이상 탐지 알람은 SOC 계정에서 관리
# WAF 로그가 CloudWatch → SOC Lambda → SOC S3로 전송되므로
# 알람/알림 처리는 SOC 측 책임. prod에서는 구성하지 않음.
# ============================================================
