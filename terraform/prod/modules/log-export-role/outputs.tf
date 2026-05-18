# ============================================================
# log-export-role 모듈 출력값
# ============================================================
# SOC 팀에 ARN 전달용. SOC Lambda 설정에 이 ARN 필요.
# ============================================================

output "role_arn" {
  description = "fin-cloudwatch-export-role ARN (SOC Lambda가 AssumeRole 시 사용)"
  value       = aws_iam_role.cloudwatch_export.arn
}

output "role_name" {
  description = "fin-cloudwatch-export-role 이름"
  value       = aws_iam_role.cloudwatch_export.name
}