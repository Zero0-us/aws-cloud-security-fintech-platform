variable "audit_log_retention_days" {
  description = "CloudWatch retention days for dev audit log groups"
  type        = number
  default     = 30
}

variable "soc_log_bucket_name" {
  description = "SOC central S3 bucket for dev CloudTrail, AWS Config, WAF, and ALB logs"
  type        = string
  default     = "fin-dev-log-s3"
}

variable "soc_log_kms_key_arn" {
  description = "SOC KMS key ARN for central log bucket encryption. Leave empty until the SOC key ARN is available."
  type        = string
  default     = ""
}

variable "cloudtrail_s3_key_prefix" {
  description = "SOC S3 prefix for dev CloudTrail logs"
  type        = string
  default     = "soc-logs/cloudtrail/dev"
}

variable "config_s3_key_prefix" {
  description = "SOC S3 prefix for dev AWS Config snapshots/history"
  type        = string
  default     = "soc-logs/config/dev"
}

variable "alb_access_logs_prefix" {
  description = "SOC S3 prefix for dev ALB access logs"
  type        = string
  default     = "alb"
}

variable "soc_export_principal_arn" {
  description = "SOC IAM principal allowed to assume fin-cloudwatch-export-role"
  type        = string
  default     = "arn:aws:iam::399707826519:root"
}

variable "cloudwatch_export_role_name" {
  description = "IAM role assumed by SOC automation to export dev CloudWatch Logs"
  type        = string
  default     = "fin-cloudwatch-export-role"
}

locals {
  dev_cloudtrail_name    = "fin-dev-cloudtrail"
  dev_vpc_flow_log_group = "/aws/vpc/flowlogs/fin-dev-vpc"
  dev_config_recorder    = "fin-dev-config-recorder"
  dev_waf_log_group      = "aws-waf-logs-fin-dev-waf"

  audit_tags = {
    Environment = "dev"
    Component   = "audit"
  }
}

resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/aws/cloudtrail/${local.dev_cloudtrail_name}"
  retention_in_days = var.audit_log_retention_days
  tags              = local.audit_tags
}

data "aws_iam_policy_document" "cloudtrail_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "cloudtrail_logs" {
  name               = "fin-dev-cloudtrail-logs-role"
  assume_role_policy = data.aws_iam_policy_document.cloudtrail_assume_role.json
  tags               = local.audit_tags
}

data "aws_iam_policy_document" "cloudtrail_logs" {
  statement {
    sid    = "AllowCloudTrailToWriteCloudWatchLogs"
    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = ["${aws_cloudwatch_log_group.cloudtrail.arn}:*"]
  }
}

resource "aws_iam_role_policy" "cloudtrail_logs" {
  name   = "fin-dev-cloudtrail-logs-policy"
  role   = aws_iam_role.cloudtrail_logs.id
  policy = data.aws_iam_policy_document.cloudtrail_logs.json
}

resource "aws_cloudtrail" "dev" {
  name                          = local.dev_cloudtrail_name
  s3_bucket_name                = var.soc_log_bucket_name
  s3_key_prefix                 = var.cloudtrail_s3_key_prefix
  kms_key_id                    = var.soc_log_kms_key_arn == "" ? null : var.soc_log_kms_key_arn
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.cloudtrail_logs.arn
  tags                          = local.audit_tags

  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }

  depends_on = [aws_iam_role_policy.cloudtrail_logs]
}

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = local.dev_vpc_flow_log_group
  retention_in_days = var.audit_log_retention_days
  tags              = local.audit_tags
}

data "aws_iam_policy_document" "vpc_flow_logs_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "vpc_flow_logs" {
  name               = "fin-dev-vpc-flow-logs-role"
  assume_role_policy = data.aws_iam_policy_document.vpc_flow_logs_assume_role.json
  tags               = local.audit_tags
}

data "aws_iam_policy_document" "vpc_flow_logs" {
  statement {
    sid    = "AllowVpcFlowLogsToWriteCloudWatchLogs"
    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams"
    ]

    resources = ["${aws_cloudwatch_log_group.vpc_flow_logs.arn}:*"]
  }
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  name   = "fin-dev-vpc-flow-logs-policy"
  role   = aws_iam_role.vpc_flow_logs.id
  policy = data.aws_iam_policy_document.vpc_flow_logs.json
}

resource "aws_flow_log" "vpc" {
  log_destination          = aws_cloudwatch_log_group.vpc_flow_logs.arn
  iam_role_arn             = aws_iam_role.vpc_flow_logs.arn
  traffic_type             = "ALL"
  vpc_id                   = aws_vpc.dev.id
  max_aggregation_interval = 60
  tags                     = merge(local.audit_tags, { Name = "fin-dev-vpc-flow-logs" })

  depends_on = [aws_iam_role_policy.vpc_flow_logs]
}

data "aws_iam_policy_document" "config_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "config" {
  name               = "fin-dev-config-role"
  assume_role_policy = data.aws_iam_policy_document.config_assume_role.json
  tags               = local.audit_tags
}

resource "aws_iam_role_policy_attachment" "config_managed" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_config_configuration_recorder" "dev" {
  name     = local.dev_config_recorder
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }

  depends_on = [aws_iam_role_policy_attachment.config_managed]
}

resource "aws_config_delivery_channel" "dev" {
  name           = "fin-dev-config-delivery-channel"
  s3_bucket_name = var.soc_log_bucket_name
  s3_key_prefix  = var.config_s3_key_prefix
  s3_kms_key_arn = var.soc_log_kms_key_arn == "" ? null : var.soc_log_kms_key_arn

  snapshot_delivery_properties {
    delivery_frequency = "TwentyFour_Hours"
  }

  depends_on = [aws_config_configuration_recorder.dev]
}

resource "aws_config_configuration_recorder_status" "dev" {
  name       = aws_config_configuration_recorder.dev.name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.dev]
}

locals {
  dev_config_rules = {
    "soc-cloudtrail-enabled" = {
      source_identifier = "CLOUD_TRAIL_ENABLED"
      description       = "Checks whether CloudTrail is enabled."
    }
    "soc-s3-public-read-prohibited" = {
      source_identifier = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
      description       = "Checks whether S3 buckets prohibit public read access."
    }
    "soc-s3-public-write-prohibited" = {
      source_identifier = "S3_BUCKET_PUBLIC_WRITE_PROHIBITED"
      description       = "Checks whether S3 buckets prohibit public write access."
    }
    "soc-s3-encryption-enabled" = {
      source_identifier = "S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED"
      description       = "Checks whether S3 buckets have server-side encryption enabled."
    }
    "soc-vpc-flow-logs-enabled" = {
      source_identifier = "VPC_FLOW_LOGS_ENABLED"
      description       = "Checks whether VPC Flow Logs are enabled."
    }
    "soc-incoming-ssh-disabled" = {
      source_identifier = "INCOMING_SSH_DISABLED"
      description       = "Checks whether security groups restrict unrestricted SSH access."
    }
    "soc-iam-user-mfa-enabled" = {
      source_identifier = "IAM_USER_MFA_ENABLED"
      description       = "Checks whether IAM users have MFA enabled."
    }
    "soc-root-account-mfa-enabled" = {
      source_identifier = "ROOT_ACCOUNT_MFA_ENABLED"
      description       = "Checks whether the root account has MFA enabled."
    }
  }
}

resource "aws_config_config_rule" "managed" {
  for_each    = local.dev_config_rules
  name        = each.key
  description = each.value.description

  source {
    owner             = "AWS"
    source_identifier = each.value.source_identifier
  }

  depends_on = [aws_config_configuration_recorder_status.dev]
}

resource "aws_cloudwatch_log_group" "waf" {
  name              = local.dev_waf_log_group
  retention_in_days = var.audit_log_retention_days
  tags              = local.audit_tags
}

resource "aws_wafv2_web_acl_logging_configuration" "dev" {
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]
  resource_arn            = aws_wafv2_web_acl.dev.arn
}

data "aws_iam_policy_document" "cloudwatch_export_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [var.soc_export_principal_arn]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "cloudwatch_export" {
  name               = var.cloudwatch_export_role_name
  assume_role_policy = data.aws_iam_policy_document.cloudwatch_export_assume_role.json
  tags               = local.audit_tags
}

data "aws_iam_policy_document" "cloudwatch_export" {
  statement {
    sid    = "AllowCloudWatchLogsExport"
    effect = "Allow"

    actions = [
      "logs:CreateExportTask",
      "logs:CancelExportTask",
      "logs:DescribeExportTasks",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:FilterLogEvents",
      "logs:GetLogEvents"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "cloudwatch_export" {
  name   = "${var.cloudwatch_export_role_name}-policy"
  role   = aws_iam_role.cloudwatch_export.id
  policy = data.aws_iam_policy_document.cloudwatch_export.json
}
