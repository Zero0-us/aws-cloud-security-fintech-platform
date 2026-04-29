output "audit_vpc_id" {
  description = "Audit VPC ID"
  value       = aws_vpc.audit_vpc.id
}

output "audit_vpc_cidr" {
  description = "Audit VPC CIDR block"
  value       = aws_vpc.audit_vpc.cidr_block
}

output "audit_bastion_subnet_2a_id" {
  description = "Audit Bastion Subnet 2a ID"
  value       = aws_subnet.bastion_subnet_2a.id
}

output "audit_bastion_subnet_2c_id" {
  description = "Audit Bastion Subnet 2c ID"
  value       = aws_subnet.bastion_subnet_2c.id
}

output "audit_tgw_subnet_2a_id" {
  description = "Audit TGW Subnet 2a ID"
  value       = aws_subnet.tgw_subnet_2a.id
}

output "audit_tgw_subnet_2c_id" {
  description = "Audit TGW Subnet 2c ID"
  value       = aws_subnet.tgw_subnet_2c.id
}

output "s3_cmk_arn" {
  description = "S3 KMS CMK ARN"
  value       = aws_kms_key.s3_cmk.arn
}

output "soc_audit_log_bucket_name" {
  description = "SOC audit log bucket name"
  value       = aws_s3_bucket.soc_audit_log_bucket.id
}

output "soc_compliance_bucket_name" {
  description = "SOC compliance bucket name"
  value       = aws_s3_bucket.soc_compliance_bucket.id
}

output "soc_athena_results_bucket_name" {
  description = "SOC Athena query results bucket name"
  value       = aws_s3_bucket.soc_athena_results_bucket.id
}

output "bastion_instance_id" {
  description = "Bastion EC2 Instance ID"
  value       = aws_instance.bastion.id
}

# ============================================================================
# VPC Flow Logs Outputs
# ============================================================================

output "vpc_flow_logs_group_name" {
  description = "CloudWatch Logs Group Name for VPC Flow Logs"
  value       = aws_cloudwatch_log_group.vpc_flow_logs.name
}

output "vpc_flow_logs_group_arn" {
  description = "CloudWatch Logs Group ARN for VPC Flow Logs"
  value       = aws_cloudwatch_log_group.vpc_flow_logs.arn
}

# ============================================================================
# CloudTrail Outputs
# ============================================================================

output "cloudtrail_arn" {
  description = "CloudTrail ARN"
  value       = aws_cloudtrail.audit_trail.arn
}

output "cloudtrail_s3_bucket" {
  description = "S3 bucket for CloudTrail logs"
  value       = aws_cloudtrail.audit_trail.s3_bucket_name
}

# ============================================================================
# Athena Outputs
# ============================================================================

output "athena_database_name" {
  description = "Athena/Glue database for SOC log analysis"
  value       = aws_glue_catalog_database.soc_logs.name
}

output "athena_workgroup_name" {
  description = "Athena workgroup for SOC log analysis"
  value       = aws_athena_workgroup.soc_logs.name
}

output "athena_query_results_location" {
  description = "S3 location for Athena query results"
  value       = "s3://${aws_s3_bucket.soc_athena_results_bucket.id}/sc-audit/"
}

# ============================================================================
# Compliance Monitoring Outputs
# ============================================================================

output "soc_audit_notifications_topic_arn" {
  description = "SNS topic ARN for SOC audit and compliance notifications"
  value       = aws_sns_topic.soc_audit_notifications.arn
}

output "monthly_audit_report_schedule" {
  description = "EventBridge schedule expression for monthly audit report notification"
  value       = aws_cloudwatch_event_rule.monthly_audit_report.schedule_expression
}

# ============================================================================
# Routing Outputs
# ============================================================================

output "bastion_route_table_id" {
  description = "Bastion Subnet Route Table ID"
  value       = aws_route_table.bastion_rt.id
}

output "tgw_route_table_id" {
  description = "TGW Subnet Route Table ID"
  value       = aws_route_table.tgw_rt.id
}

# ============================================================================
# GuardDuty Outputs
# ============================================================================

output "guardduty_detector_id" {
  description = "GuardDuty Detector ID"
  value       = var.enable_guardduty ? aws_guardduty_detector.main[0].id : null
}

# ============================================================================
# Security Hub Outputs
# ============================================================================

output "securityhub_status" {
  description = "Security Hub Status"
  value       = var.enable_securityhub ? "Enabled with CIS and PCI DSS standards" : "Disabled"
}

output "bastion_public_ip" {
  description = "Bastion Public IP Address"
  value       = aws_instance.bastion.public_ip
}

output "bastion_security_group_id" {
  description = "Bastion Security Group ID"
  value       = aws_security_group.bastion_sg.id
}

output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = aws_internet_gateway.audit_igw.id
}
