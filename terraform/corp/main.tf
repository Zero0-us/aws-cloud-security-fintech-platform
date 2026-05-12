# VPC 모듈 호출
module "corp_vpc" {
  source = "./modules/vpc"

  env_name           = var.env_name
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  public_subnets     = var.public_subnets
}

# VPN 모듈 호출 (EIP Allocation ID가 입력된 경우에만)
module "corp_vpn" {
  source = "./modules/vpn"
  count  = var.corp_eip_allocation_id != "" ? 1 : 0

  env_name               = var.env_name
  vpc_id                 = module.corp_vpc.vpc_id
  vpc_cidr               = var.vpc_cidr
  public_subnet_id       = module.corp_vpc.public_subnet_ids[0]
  public_route_table_id  = module.corp_vpc.public_route_table_id
  corp_eip_allocation_id = var.corp_eip_allocation_id
  target_accounts        = var.target_accounts
}
