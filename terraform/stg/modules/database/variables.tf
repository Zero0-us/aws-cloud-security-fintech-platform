# modules/database/variables.tf

variable "env_name" {
  description = "배포 환경 구분 (prod, dev 등)"
  type        = string
}

variable "db_subnet_ids" {
  description = "RDS가 위치할 전용 DB 서브넷 ID 리스트"
  type        = list(string)
}

variable "db_sg_id" {
  description = "RDS에 적용할 보안 그룹 ID"
  type        = string
}

variable "is_prod_deployment" {
  description = "운영 환경 여부에 따른 Multi-AZ 활성화 제어"
  type        = bool
  default     = false
}
