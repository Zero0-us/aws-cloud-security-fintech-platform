# ============================================================
# log-export-role 모듈 변수
# ============================================================
# SOC 계정의 중앙 Lambda가 이 Role을 AssumeRole하여
# 각 계정의 CloudWatch Logs를 SOC S3로 export하는 용도.
#
# 적용 대상: Stg / Dev / Stg 3개 계정 공통
# ============================================================

variable "env_name" {
  description = "Environment name (stg, dev, stg)"
  type        = string
}

variable "soc_account_id" {
  description = "SOC AWS 계정 ID. 이 계정의 Lambda가 AssumeRole 가능."
  type        = string
}

variable "soc_lambda_role_name" {
  description = "SOC 계정의 Lambda 실행 Role 이름. 비어있으면 SOC 계정 전체에서 AssumeRole 가능."
  type        = string
  default     = ""
}