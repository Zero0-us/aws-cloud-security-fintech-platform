module "stg_vpc" {
  source          = "./modules/vpc"
  env_name        = var.env_name
  vpc_cidr        = var.vpc_cidr
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets
  db_subnets      = var.db_subnets
  azs             = var.availability_zones
}

module "stg_security" {
  source          = "./modules/security"
  env_name        = var.env_name
  vpc_id          = module.stg_vpc.vpc_id
  app_cidr_blocks = var.private_subnets
}

module "stg_db" {
  source             = "./modules/database"
  env_name           = var.env_name
  db_subnet_ids      = module.stg_vpc.db_subnet_ids
  db_sg_id           = module.stg_security.db_sg_id
  is_prod_deployment = var.is_prod_deployment
}

module "stg_eks" {
  source = "./modules/eks"

  node_group_name = var.node_group_name
  region          = var.region
  aws_profile     = var.aws_profile

  env_name        = var.env_name
  vpc_id          = module.stg_vpc.vpc_id
  private_subnets = module.stg_vpc.private_subnet_ids

  access_entries = var.eks_access_entries

  depends_on = [module.stg_vpc]
}

module "stg_waf" {
  source   = "./modules/waf"
  env_name = var.env_name
}

module "stg_iam" {
  source      = "./modules/iam"
  env_name    = var.env_name
  name_prefix = "fin-${var.env_name}"
  iam_users   = var.iam_users
}

module "stg_audit" {
  source             = "./modules/audit"
  env_name           = var.env_name
  name_prefix        = "fin-${var.env_name}"
  log_retention_days = var.audit_log_retention_days
}

data "aws_lb" "active_ingress_alb" {
  count = var.active_ingress_alb_name == "" ? 0 : 1
  name  = var.active_ingress_alb_name
}

module "stg_route53" {
  source   = "./modules/route53"
  env_name = var.env_name

  alb_dns_name = var.active_ingress_alb_name == "" ? "" : data.aws_lb.active_ingress_alb[0].dns_name
  alb_zone_id  = var.active_ingress_alb_name == "" ? "" : data.aws_lb.active_ingress_alb[0].zone_id
}

# ============================================================
# fin-cloudwatch-export-role
# ============================================================
# SOC 중앙 Lambda가 CloudWatch Logs를 S3로 export할 때 사용하는 Role.
# EKS/RDS/WAF 로그는 S3 직접 전송이 안 되므로 SOC Lambda가 가져감.
# ============================================================
module "stg_log_export_role" {
  source = "./modules/log-export-role"

  env_name             = var.env_name
  soc_account_id       = var.soc_account_id
  soc_lambda_role_name = var.soc_lambda_role_name
}