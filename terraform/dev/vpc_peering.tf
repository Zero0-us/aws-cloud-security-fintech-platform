# ============================================================
# vpc_peering.tf — VPC 피어링 (Dev ↔ Security/Audit)
# ============================================================
# VPC 피어링 = 서로 다른 VPC(다른 계정도 가능)를 연결하는 터널.
# 피어링하면 두 VPC가 같은 네트워크처럼 통신 가능.
#
# Dev VPC (10.30.0.0/16, 계정 364585378962)
#   ↔ 피어링 ↔
# Security/Audit VPC (10.10.0.0/16, 계정 399707826519)
#
# ⚠️ 피어링은 2단계:
#   1. 요청자(Dev)가 피어링 요청 → 이 파일에서 생성
#   2. 수락자(Security)가 수락 → 상대 계정에서 콘솔로 수락해야 함!

# ────────────────────────────────────────────
# 1. VPC 피어링 요청
# ────────────────────────────────────────────
# Dev 계정에서 Security 계정으로 피어링 요청을 보냄.
# peer_owner_id = 상대 AWS 계정 ID
# peer_vpc_id = 상대 VPC ID

resource "aws_vpc_peering_connection" "dev_to_security" {
  vpc_id        = aws_vpc.dev.id                  # 내 VPC (Dev)
  peer_vpc_id   = "vpc-0e26f310a98b9d0f8"         # 상대 VPC (Security)
  peer_owner_id = "399707826519"                   # 상대 AWS 계정 ID
  peer_region   = "ap-northeast-2"                 # 같은 리전

  tags = {
    Name = "fin-dev-to-audit-peering"
  }
}

# ────────────────────────────────────────────
# 2. 라우팅 테이블에 상대 VPC CIDR 추가
# ────────────────────────────────────────────
# 피어링만 만들면 안 됨!
# "10.10.0.0/16으로 가는 트래픽은 피어링을 통해 보내라"
# 라우팅 규칙을 추가해야 실제 통신이 됨.

# Private 서브넷 → Security VPC (EKS 노드가 보안 로그 전송 등)
resource "aws_route" "pri_to_security" {
  route_table_id            = aws_route_table.pri.id
  destination_cidr_block    = "10.10.0.0/16"                              # Security VPC CIDR
  vpc_peering_connection_id = aws_vpc_peering_connection.dev_to_security.id
}

# Public 서브넷 → Security VPC (필요 시)
resource "aws_route" "pub_to_security" {
  route_table_id            = aws_route_table.pub.id
  destination_cidr_block    = "10.10.0.0/16"
  vpc_peering_connection_id = aws_vpc_peering_connection.dev_to_security.id
}
