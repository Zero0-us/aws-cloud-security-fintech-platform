# ============================================================
# monitoring.tf — STG → Audit Account (SOC) 로그 전송
# ============================================================
# draw.io 기준:
#   Staging Account: VPC Flow Logs, CloudTrail, AWS Config, CloudWatch Logs
#   Audit Account (SOC): fin-stg-log-s3, CloudWatch Logs, Athena, Glue, GuardDuty, Security Hub
#
# 이 파일은 STG 계정에서 생성 가능한 로그 송신 리소스만 관리합니다.
# SOC 계정의 S3 버킷/버킷 정책/KMS/Athena/Glue/GuardDuty/Security Hub는 SOC 계정에서 관리합니다.

locals {
  soc_log_bucket_name   = var.soc_log_bucket_name != "" ? var.soc_log_bucket_name : "fin-${var.env_name}-log-s3"
  soc_log_bucket_prefix = var.soc_log_bucket_prefix != "" ? trim(var.soc_log_bucket_prefix, "/") : var.env_name
  soc_log_bucket_arn    = "arn:aws:s3:::${local.soc_log_bucket_name}"

  soc_vpc_flow_logs_prefix = "${local.soc_log_bucket_prefix}/vpc-flow-logs"
  soc_cloudtrail_prefix    = "${local.soc_log_bucket_prefix}/cloudtrail"
  soc_config_prefix        = "${local.soc_log_bucket_prefix}/config"
}

# ============================================================
# VPC Flow Logs → CloudWatch Logs
# ============================================================
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  count = var.enable_soc_monitoring ? 1 : 0

  name              = "/aws/vpc/fin-${var.env_name}-flow-logs"
  retention_in_days = var.soc_monitoring_retention_days

  tags = {
    Name = "fin-${var.env_name}-flow-logs"
  }
}

resource "aws_iam_role" "vpc_flow_logs" {
  count = var.enable_soc_monitoring ? 1 : 0

  name = "fin-${var.env_name}-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  count = var.enable_soc_monitoring ? 1 : 0

  name = "fin-${var.env_name}-vpc-flow-logs-policy"
  role = aws_iam_role.vpc_flow_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_flow_log" "vpc_to_cloudwatch" {
  count = var.enable_soc_monitoring ? 1 : 0

  log_destination      = aws_cloudwatch_log_group.vpc_flow_logs[0].arn
  log_destination_type = "cloud-watch-logs"
  iam_role_arn         = aws_iam_role.vpc_flow_logs[0].arn
  traffic_type         = "ALL"
  vpc_id               = module.prod_vpc.vpc_id

  tags = {
    Name = "fin-${var.env_name}-vpc-flow-logs-cw"
  }
}

# ============================================================
# VPC Flow Logs → SOC S3 (fin-stg-log-s3)
# ============================================================
resource "aws_flow_log" "vpc_to_soc_s3" {
  count = var.enable_soc_monitoring ? 1 : 0

  log_destination      = "${local.soc_log_bucket_arn}/${local.soc_vpc_flow_logs_prefix}"
  log_destination_type = "s3"
  traffic_type         = "ALL"
  vpc_id               = module.prod_vpc.vpc_id

  tags = {
    Name = "fin-${var.env_name}-vpc-flow-logs-soc-s3"
  }
}

# ============================================================
# CloudTrail → CloudWatch Logs + SOC S3
# ============================================================
resource "aws_cloudwatch_log_group" "cloudtrail" {
  count = var.enable_soc_monitoring ? 1 : 0

  name              = "/aws/cloudtrail/fin-${var.env_name}"
  retention_in_days = var.soc_monitoring_retention_days

  tags = {
    Name = "fin-${var.env_name}-cloudtrail"
  }
}

resource "aws_iam_role" "cloudtrail_cloudwatch" {
  count = var.enable_soc_monitoring ? 1 : 0

  name = "fin-${var.env_name}-cloudtrail-cloudwatch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "cloudtrail_cloudwatch" {
  count = var.enable_soc_monitoring ? 1 : 0

  name = "fin-${var.env_name}-cloudtrail-cloudwatch-policy"
  role = aws_iam_role.cloudtrail_cloudwatch[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.cloudtrail[0].arn}:*"
      }
    ]
  })
}

resource "aws_cloudtrail" "soc_audit" {
  count = var.enable_soc_monitoring ? 1 : 0

  name                          = "fin-${var.env_name}-cloudtrail"
  s3_bucket_name                = local.soc_log_bucket_name
  s3_key_prefix                 = local.soc_cloudtrail_prefix
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.cloudtrail[0].arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.cloudtrail_cloudwatch[0].arn

  depends_on = [aws_iam_role_policy.cloudtrail_cloudwatch]

  tags = {
    Name = "fin-${var.env_name}-cloudtrail"
  }
}

# ============================================================
# AWS Config → SOC S3
# ============================================================
resource "aws_iam_role" "config" {
  count = var.enable_soc_monitoring ? 1 : 0

  name = "fin-${var.env_name}-aws-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "config" {
  count = var.enable_soc_monitoring ? 1 : 0

  role       = aws_iam_role.config[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_config_configuration_recorder" "soc_audit" {
  count = var.enable_soc_monitoring ? 1 : 0

  name     = "fin-${var.env_name}-config-recorder"
  role_arn = aws_iam_role.config[0].arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }

  depends_on = [aws_iam_role_policy_attachment.config]
}

resource "aws_config_delivery_channel" "soc_audit" {
  count = var.enable_soc_monitoring ? 1 : 0

  name           = "fin-${var.env_name}-config-delivery"
  s3_bucket_name = local.soc_log_bucket_name
  s3_key_prefix  = local.soc_config_prefix

  depends_on = [aws_config_configuration_recorder.soc_audit]
}

resource "aws_config_configuration_recorder_status" "soc_audit" {
  count = var.enable_soc_monitoring ? 1 : 0

  name       = aws_config_configuration_recorder.soc_audit[0].name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.soc_audit]
}
