variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "ap-northeast-2"
}

variable "project_name" {
  description = "Project name for tagging"
  type        = string
  default     = "fintech-security-platform"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "audit"
}

variable "owner" {
  description = "Owner name for tagging"
  type        = string
  default     = "security-team"
}

variable "vpc_name" {
  description = "VPC name"
  type        = string
  default     = "fin-audit-vpc"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.10.0.0/16"
}

variable "enable_dns_support" {
  description = "Enable DNS support in VPC"
  type        = bool
  default     = true
}

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in VPC"
  type        = bool
  default     = true
}

variable "bastion_subnet_2a_cidr" {
  description = "CIDR block for bastion subnet in 2a"
  type        = string
  default     = "10.10.10.0/24"
}

variable "bastion_subnet_2c_cidr" {
  description = "CIDR block for bastion subnet in 2c"
  type        = string
  default     = "10.10.11.0/24"
}

variable "tgw_subnet_2a_cidr" {
  description = "CIDR block for TGW subnet in 2a"
  type        = string
  default     = "10.10.100.0/24"
}

variable "tgw_subnet_2c_cidr" {
  description = "CIDR block for TGW subnet in 2c"
  type        = string
  default     = "10.10.101.0/24"
}

variable "kms_key_name" {
  description = "KMS key name for S3 encryption"
  type        = string
  default     = "fin-s3-cmk"
}

variable "kms_key_alias" {
  description = "KMS key alias for S3 encryption"
  type        = string
  default     = "alias/fin-s3-cmk"
}

variable "kms_deletion_window" {
  description = "KMS key deletion window in days"
  type        = number
  default     = 7
}

variable "soc_audit_log_bucket_name" {
  description = "SOC audit log archive bucket name"
  type        = string
  default     = "fin-prod-log-s3"
}

variable "dev_log_bucket_name" {
  description = "Development log bucket name"
  type        = string
  default     = "fin-dev-log-s3"
}

variable "stage_log_bucket_name" {
  description = "Staging log bucket name"
  type        = string
  default     = "fin-stage-log-s3"
}

variable "soc_athena_results_bucket_name" {
  description = "SOC Athena query results bucket name"
  type        = string
  default     = "fin-athena-results"
}

variable "bastion_instance_type" {
  description = "EC2 instance type for bastion"
  type        = string
  default     = "t3.micro"
}

variable "bastion_key_pair_name" {
  description = "SSH key pair name for bastion instance"
  type        = string
  default     = ""
}

variable "bastion_allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to SSH to the bastion. Keep empty to disable direct SSH ingress."
  type        = list(string)
  default     = []
}

# ============================================================================
# Transit Gateway (TGW) Variables
# ============================================================================

variable "transit_gateway_id" {
  description = "Transit Gateway ID for cross-VPC communication"
  type        = string
  default     = ""
}

variable "prod_vpc_peering_connection_id" {
  description = "VPC peering connection ID from Audit/SOC VPC to Production VPC"
  type        = string
  default     = ""
}

variable "dev_vpc_peering_connection_id" {
  description = "VPC peering connection ID from Audit/SOC VPC to Development VPC"
  type        = string
  default     = ""
}

variable "stage_vpc_peering_connection_id" {
  description = "VPC peering connection ID from Audit/SOC VPC to Staging VPC"
  type        = string
  default     = ""
}

variable "prod_account_id" {
  description = "Production AWS account ID allowed to deliver logs into the SOC log archive"
  type        = string
  default     = ""
}

variable "dev_account_id" {
  description = "Development AWS account ID allowed to deliver logs into the SOC log archive"
  type        = string
  default     = ""
}

variable "stage_account_id" {
  description = "Staging AWS account ID allowed to deliver logs into the SOC log archive"
  type        = string
  default     = ""
}

variable "enable_guardduty" {
  description = "Enable GuardDuty detector. Disable this for accounts without GuardDuty subscription access."
  type        = bool
  default     = false
}

variable "enable_securityhub" {
  description = "Enable Security Hub and standards. Disable this for accounts without Security Hub subscription access."
  type        = bool
  default     = false
}

variable "prod_vpc_cidr" {
  description = "Production VPC CIDR block"
  type        = string
  default     = "10.20.0.0/16"
}

variable "dev_vpc_cidr" {
  description = "Development VPC CIDR block"
  type        = string
  default     = "10.30.0.0/16"
}

variable "stage_vpc_cidr" {
  description = "Staging VPC CIDR block"
  type        = string
  default     = "10.40.0.0/16"
}

# ============================================================================
# VPC Flow Logs Variables
# ============================================================================

variable "flow_logs_retention_days" {
  description = "CloudWatch Logs retention period for VPC Flow Logs (in days)"
  type        = number
  default     = 30
}

variable "flow_logs_traffic_type" {
  description = "VPC Flow Logs traffic type (ACCEPT, REJECT, or ALL)"
  type        = string
  default     = "ALL"
}

variable "athena_database_name" {
  description = "Athena/Glue database name for SOC log analysis"
  type        = string
  default     = "fin_soc_logs"
}

variable "athena_workgroup_name" {
  description = "Athena workgroup name for SOC log analysis"
  type        = string
  default     = "fin-soc-athena-wg"
}

variable "audit_notification_email" {
  description = "Email address for SOC compliance and monthly audit notifications. Leave empty to skip email subscription."
  type        = string
  default     = ""
}

variable "monthly_audit_schedule_expression" {
  description = "EventBridge schedule expression for monthly audit report notification"
  type        = string
  default     = "cron(0 0 1 * ? *)"
}
