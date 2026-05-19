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
# WAF 차단 이벤트 이상 탐지 알람
# ============================================================
# WAF가 SQLi/XSS 등을 차단하면 BlockedRequests 메트릭이 증가함.
# 5분 내 차단 건수가 임계값 초과 시 SNS로 알림 발송.
# ============================================================

resource "aws_sns_topic" "waf_alerts" {
  name = "fin-${var.env_name}-waf-alerts"
}

resource "aws_sns_topic_subscription" "waf_alerts_email" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.waf_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "waf_blocked_requests" {
  alarm_name          = "fin-${var.env_name}-waf-blocked-requests"
  alarm_description   = "WAF 차단 요청 급증 탐지 — SQLi/XSS 공격 의심"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = 300
  statistic           = "Sum"
  threshold           = var.waf_block_alarm_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    WebACL = "fin-${var.env_name}-waf"
    Region = "ap-northeast-2"
    Rule   = "ALL"
  }

  alarm_actions = [aws_sns_topic.waf_alerts.arn]
  ok_actions    = [aws_sns_topic.waf_alerts.arn]
}
