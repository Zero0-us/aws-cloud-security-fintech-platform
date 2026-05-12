# 팀원에게 전달할 정보
output "corp_account_id" {
  description = "Corp Account ID (팀원에게 전달용)"
  value       = data.aws_caller_identity.current.account_id
}

output "corp_vpc_cidr" {
  description = "Corp VPC CIDR (팀원에게 전달용)"
  value       = var.vpc_cidr
}

# 내부 참조용
output "vpc_id" {
  description = "VPC ID"
  value       = module.corp_vpc.vpc_id
}

# 현재 계정 정보
data "aws_caller_identity" "current" {}

# 배포 완료 후 팀원에게 전달할 정보 출력
output "share_with_team" {
  description = "팀원에게 전달할 정보"
  value = {
    corp_account_id = data.aws_caller_identity.current.account_id
    corp_vpc_cidr   = var.vpc_cidr
  }
}

# 각 계정별 터널 IP 출력 (팀원 전달용)
output "vpn_tunnel_ips" {
  description = "Corp VPN EIP (Dev팀에 전달할 IP)"
  value = length(module.corp_vpn) > 0 ? module.corp_vpn[0].corp_eip : ""
}