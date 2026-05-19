# ============================================================
# vpc.tf — SOC S3 Gateway Endpoint
# ============================================================
# VPC, 서브넷, 라우팅 테이블, 피어링 경로는 모두 main.tf에서 관리.
# (aws_vpc.audit_vpc, aws_subnet.peering_subnet_*, aws_route_table.peering_rt)
# ============================================================

# ============================================================
# S3 VPC Endpoint (Gateway)
# ============================================================
# peering 서브넷에서 S3로 가는 트래픽을 AWS 내부 경로로 처리.
# IGW/NAT 없이 S3 접근 가능 → 비용 절감 + 외부 노출 없음.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.audit_vpc.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    aws_route_table.peering_rt.id
  ]

  tags = {
    Name = "fin-soc-s3-endpoint"
  }
}
