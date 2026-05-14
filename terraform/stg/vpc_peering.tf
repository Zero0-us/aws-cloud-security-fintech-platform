# ============================================================
# vpc_peering.tf — VPC 피어링 (STG ↔ Audit Account / SOC)
# ============================================================
# STG VPC
#   ↔ 피어링 ↔
# Audit Account (SOC) VPC
#
# 피어링은 2단계로 완료됩니다.
#   1. 요청자(STG)가 피어링 요청 → 이 파일에서 생성
#   2. 수락자(Audit Account / SOC)가 요청 수락 → SOC 계정에서 수락 및 역방향 라우팅 추가

locals {
  effective_soc_vpc_id     = var.soc_vpc_id != "" ? var.soc_vpc_id : var.audit_vpc_id
  effective_soc_account_id = var.audit_account_id != "" ? var.audit_account_id : var.soc_account_id
}

moved {
  from = aws_vpc_peering_connection.prod_to_security
  to   = aws_vpc_peering_connection.stg_to_audit_soc
}

moved {
  from = aws_route.pri_to_security
  to   = aws_route.private_to_audit_soc
}

moved {
  from = aws_route.pub_to_security
  to   = aws_route.public_to_audit_soc
}

moved {
  from = aws_route.db_to_soc
  to   = aws_route.db_to_audit_soc
}

# ────────────────────────────────────────────
# 1. VPC 피어링 요청
# ────────────────────────────────────────────
resource "aws_vpc_peering_connection" "stg_to_audit_soc" {
  count = local.effective_soc_vpc_id != "" ? 1 : 0

  vpc_id        = module.prod_vpc.vpc_id
  peer_vpc_id   = local.effective_soc_vpc_id
  peer_owner_id = local.effective_soc_account_id != "" ? local.effective_soc_account_id : null
  peer_region   = var.region

  tags = {
    Name        = "fin-${var.env_name}-to-audit-soc-peering"
    SourceVpc   = "fin-${var.env_name}-vpc"
    PeerAccount = "audit-soc"
  }
}

# ────────────────────────────────────────────
# 2. 라우팅 테이블에 SOC VPC CIDR 추가
# ────────────────────────────────────────────
# SOC 대역으로 가는 트래픽을 VPC 피어링으로 보냅니다.

# Private 서브넷 → SOC VPC (EKS 노드가 보안 로그 전송)
resource "aws_route" "private_to_audit_soc" {
  count = local.effective_soc_vpc_id != "" ? 1 : 0

  route_table_id            = module.prod_vpc.private_route_table_id
  destination_cidr_block    = var.soc_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.stg_to_audit_soc[0].id
}

# Public 서브넷 → SOC VPC
resource "aws_route" "public_to_audit_soc" {
  count = local.effective_soc_vpc_id != "" ? 1 : 0

  route_table_id            = module.prod_vpc.public_route_table_id
  destination_cidr_block    = var.soc_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.stg_to_audit_soc[0].id
}

# DB 서브넷 → SOC VPC
resource "aws_route" "db_to_audit_soc" {
  count = local.effective_soc_vpc_id != "" ? 1 : 0

  route_table_id            = module.prod_vpc.db_route_table_id
  destination_cidr_block    = var.soc_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.stg_to_audit_soc[0].id
}
