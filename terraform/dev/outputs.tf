# ============================================================
# outputs.tf — 생성된 리소스 정보 출력
# ============================================================
# terraform apply 완료 후 화면에 표시될 값들.
# 다른 팀원(Security, Prod)과 VPC 피어링할 때 이 값들이 필요.

output "vpc_id" {
  description = "Dev VPC ID (VPC 피어링 시 필요)"
  value       = aws_vpc.dev.id
}

output "vpc_cidr" {
  description = "Dev VPC CIDR"
  value       = aws_vpc.dev.cidr_block
}

output "eks_cluster_name" {
  description = "EKS 클러스터 이름"
  value       = aws_eks_cluster.dev.name
}

output "eks_cluster_endpoint" {
  description = "EKS API 서버 엔드포인트 (kubectl 연결용)"
  value       = aws_eks_cluster.dev.endpoint
}

output "eks_cluster_version" {
  description = "Kubernetes 버전"
  value       = aws_eks_cluster.dev.version
}

output "rds_endpoint" {
  description = "RDS 접속 주소 (EKS Pod에서 사용, MySQL 3306)"
  value       = aws_db_instance.dev.endpoint
}

output "rds_database_name" {
  description = "DB 이름"
  value       = aws_db_instance.dev.db_name
}

output "rds_engine" {
  description = "DB 엔진"
  value       = aws_db_instance.dev.engine
}

output "alb_dns_name" {
  description = "ALB 접속 주소 (브라우저에서 접속)"
  value       = aws_lb.dev.dns_name
}

output "nat_gateway_ip" {
  description = "NAT Gateway 공인 IP"
  value       = aws_eip.nat.public_ip
}

# VPC 피어링 시 상대방에게 전달할 정보
output "peering_info" {
  description = "VPC 피어링 요청 시 상대 팀에게 전달할 정보"
  value = {
    account_id = data.aws_caller_identity.current.account_id
    vpc_id     = aws_vpc.dev.id
    vpc_cidr   = aws_vpc.dev.cidr_block
    region     = "ap-northeast-2"
  }
}

