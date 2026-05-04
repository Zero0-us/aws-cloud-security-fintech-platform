# VPC의 ID를 밖으로 내보냅니다.
output "vpc_id" {
  description = "생성된 VPC의 ID입니다."
  value       = aws_vpc.this.id
}

# (나중을 위해) 퍼블릭 서브넷 ID들도 같이 내보내면 좋습니다.
output "public_subnet_ids" {
  description = "생성된 퍼블릭 서브넷들의 ID 리스트입니다."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "생성된 프라이빗 서브넷 ID 리스트"
  value       = aws_subnet.private[*].id
}

output "db_subnet_ids" {
  value = aws_subnet.db[*].id
}

# VPC Peering 라우팅에 필요한 Route Table ID
output "public_route_table_id" {
  description = "퍼블릭 라우트 테이블 ID"
  value       = aws_route_table.public.id
}

output "private_route_table_id" {
  description = "프라이빗 라우트 테이블 ID"
  value       = aws_route_table.private.id
}