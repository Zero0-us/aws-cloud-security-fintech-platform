# ALB 정보 출력 (Route 53, WAF 연동에 필요)

output "alb_arn" {
  description = "ALB의 ARN (WAF 연동용)"
  value       = aws_lb.this.arn
}

output "alb_dns_name" {
  description = "ALB의 DNS 이름 (Route 53 Alias 레코드 대상)"
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "ALB의 Hosted Zone ID (Route 53 Alias 레코드용)"
  value       = aws_lb.this.zone_id
}
