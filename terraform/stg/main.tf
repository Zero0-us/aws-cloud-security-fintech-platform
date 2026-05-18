
module "prod_vpc" {
  source          = "./modules/vpc"
  env_name        = var.env_name
  vpc_cidr        = var.vpc_cidr
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets
  db_subnets      = var.db_subnets
  azs             = var.availability_zones
}

module "prod_security" {
  source   = "./modules/security"
  env_name = var.env_name
  vpc_id   = module.prod_vpc.vpc_id # VPC 생성 후 ID를 전달받음
}

module "prod_db" {
  source             = "./modules/database"
  env_name           = var.env_name
  db_subnet_ids      = module.prod_vpc.db_subnet_ids
  db_sg_id           = module.prod_security.db_sg_id
  is_prod_deployment = var.is_prod_deployment # true → Multi-AZ 활성화 (고가용성)
}

module "prod_alb" {
  source            = "./modules/alb"
  env_name          = var.env_name
  vpc_id            = module.prod_vpc.vpc_id
  alb_sg_id         = module.prod_security.alb_sg_id
  public_subnet_ids = module.prod_vpc.public_subnet_ids
}

module "prod_eks" {
  source = "./modules/eks"

  node_group_name = var.node_group_name
  region          = var.region
  aws_profile     = var.aws_profile

  env_name        = var.env_name
  vpc_id          = module.prod_vpc.vpc_id
  private_subnets = module.prod_vpc.private_subnet_ids # 주석 풀기!

  access_entries = var.eks_access_entries

  depends_on = [module.prod_vpc]
}

# ============================================================
# AWS Load Balancer Controller (EKS 생성이 끝난 후 루트에서 실행)
# ============================================================
resource "helm_release" "alb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.7.2"

  set {
    name  = "clusterName"
    value = module.prod_eks.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  # EKS 모듈에서 만들어진 IAM Role을 서비스 어카운트에 연결합니다.
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.prod_eks.alb_controller_role_arn
  }

  set {
    name  = "region"
    value = var.region
  }

  set {
    name  = "vpcId"
    value = module.prod_vpc.vpc_id
  }

  # EKS 클러스터가 완전히 만들어진 다음에 실행되도록 의존성 부여
  depends_on = [module.prod_eks]
}

module "prod_waf" {
  source   = "./modules/waf"
  env_name = var.env_name
  alb_arn  = module.prod_alb.alb_arn
}

module "prod_route53" {
  source       = "./modules/route53"
  env_name     = var.env_name
  alb_dns_name = module.prod_alb.alb_dns_name
  alb_zone_id  = module.prod_alb.alb_zone_id
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