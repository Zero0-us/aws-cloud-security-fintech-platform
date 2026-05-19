output "rds_address" {
  value = module.prod_db.db_address
}

output "rds_endpoint" {
  value = module.prod_db.db_endpoint
}

output "rds_port" {
  value = module.prod_db.db_port
}

output "rds_db_name" {
  value = module.prod_db.db_name
}

output "rds_username" {
  value = module.prod_db.db_username
}

output "rds_secret_name" {
  value = module.prod_db.db_secret_name
}

output "vuln_bank_ecr_repository" {
  value = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/vuln-bank"
}

output "iam_group_names" {
  value = module.prod_iam.group_names
}

output "iam_user_names" {
  value = module.prod_iam.user_names
}

output "iam_user_arns" {
  value = module.prod_iam.user_arns
}

output "iam_mfa_policy_arn" {
  value = module.prod_iam.mfa_policy_arn
}

output "cloudtrail_name" {
  value = module.prod_audit.cloudtrail_name
}

output "cloudtrail_s3_bucket" {
  value = module.prod_audit.cloudtrail_s3_bucket
}

output "cloudtrail_log_group" {
  value = module.prod_audit.cloudtrail_log_group
}
