# VPC의 ID를 밖으로 내보냅니다.
output "vpc_id" {
  description = "생성된 VPC의 ID입니다."
  value       = aws_vpc.this.id
}

# 퍼블릭 서브넷 ID 리스트
output "public_subnet_ids" {
  description = "생성된 퍼블릭 서브넷들의 ID 리스트입니다."
  value       = aws_subnet.public[*].id
}

# 프라이빗 서브넷 ID 리스트
output "private_subnet_ids" {
  description = "생성된 프라이빗 서브넷 ID 리스트"
  value       = aws_subnet.private[*].id
}

# DB 서브넷 ID 리스트
output "db_subnet_ids" {
  description = "생성된 DB 서브넷 ID 리스트"
  value       = aws_subnet.db[*].id
}

# 퍼블릭 라우트 테이블 ID
output "public_route_table_id" {
  description = "퍼블릭 라우트 테이블 ID"
  value       = aws_route_table.public.id
}

# 프라이빗 라우트 테이블 ID
output "private_route_table_id" {
  description = "프라이빗 라우트 테이블 ID"
  value       = aws_route_table.private.id
}

# DB 라우트 테이블 ID
output "db_route_table_id" {
  description = "DB 라우트 테이블 ID"
  value       = aws_route_table.db.id
}

# 첫 번째 퍼블릭 서브넷 ID
# public subnet이 비어 있으면 null 반환
output "first_public_subnet_id" {
  description = "첫 번째 퍼블릭 서브넷 ID"
  value       = length(aws_subnet.public) > 0 ? aws_subnet.public[0].id : null
}
