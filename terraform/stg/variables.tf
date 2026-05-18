variable "aws_profile" {
  description = "로컬 환경의 IAM 자격 증명을 특정하기 위한 AWS CLI 프로필 명칭"
  type        = string
  default     = ""
}

variable "region" {
  description = "지연 시간 최적화 및 법규 준수를 위한 리소스 배포 대상 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "env_name" {
  description = "리소스 명명 규칙(Naming Convention) 및 환경별 설정 분리를 위한 식별자"
  type        = string
  default     = "stg"
}

variable "is_prod_deployment" {
  description = "Prod 환경 RDS Multi-AZ 활성화. 고가용성 보장을 위해 true 설정."
  type        = bool
  default     = false
}

variable "vpc_cidr" {
  description = "VPC 전체 가용 아이피 대역 정의"
  type        = string
  default     = "10.40.0.0/16"
}

variable "availability_zones" {
  description = "서비스 고가용성 보장을 위한 물리적 데이터 센터 분산 배치 기준"
  type        = list(string)
  default     = ["ap-northeast-2a", "ap-northeast-2c"]
}

variable "public_subnets" {
  description = "외부 트래픽 수용(ALB, NAT GW)을 위한 공개 주소 대역"
  type        = list(string)
  default     = ["10.40.1.0/24", "10.40.2.0/24"]
}

variable "private_subnets" {
  description = "내부 비즈니스 로직(App, EKS Nodes) 보호를 위한 비공개 주소 대역"
  type        = list(string)
  default     = ["10.40.10.0/24", "10.40.11.0/24"]
}

variable "db_subnets" {
  description = "데이터 보호를 위해 외부 및 애플리케이션 계층으로부터 격리된 DB 전용 대역"
  type        = list(string)
  default     = ["10.40.20.0/24", "10.40.21.0/24"]
}

variable "node_group_name" {
  description = "EKS 노드 그룹 이름"
  type        = string
  default     = "fin-stg-nodegroup"
}

variable "eks_access_entries" {
  description = "EKS 클러스터 권한 명단"
  type        = any
  default     = {}
}

# variable "corp_account_id" {
#   description = "Corp AWS 계정 ID (IAM Role 신뢰 주체)"
#   type        = string
#   default     = ""
# }

variable "soc_vpc_id" {
  description = "SOC VPC ID. 비어 있으면 SOC VPC peering을 생성하지 않음."
  type        = string
  default     = ""
}

variable "soc_account_id" {
  description = "SOC AWS 계정 ID"
  type        = string
  default     = ""
}

variable "soc_vpc_cidr" {
  description = "SOC VPC CIDR. STG VPC 라우팅 테이블에서 이 대역을 peering 대상으로 라우팅함."
  type        = string
  default     = "10.10.0.0/16"
}

variable "soc_log_bucket_name" {
  description = "Audit Account (SOC)에 있는 STG 로그 수집 S3 버킷명. 비어 있으면 fin-<env_name>-log-s3를 사용."
  type        = string
  default     = ""
}

variable "soc_log_bucket_prefix" {
  description = "SOC 로그 버킷 안에서 이 환경 로그를 저장할 prefix. 비어 있으면 env_name을 사용."
  type        = string
  default     = ""
}

variable "enable_soc_monitoring" {
  description = "VPC Flow Logs, CloudTrail, AWS Config를 SOC 로그 버킷으로 전송하는 리소스를 생성할지 여부."
  type        = bool
  default     = true
}

variable "soc_monitoring_retention_days" {
  description = "STG 계정 CloudWatch Logs 보관 기간"
  type        = number
  default     = 90
}

variable "audit_vpc_id" {
  description = "Deprecated: soc_vpc_id를 사용하세요. 기존 tfvars 호환용."
  type        = string
  default     = ""
}

variable "audit_account_id" {
  description = "Deprecated: soc_account_id를 사용하세요. 기존 tfvars 호환용."
  type        = string
  default     = ""
}
# ============================================================
# SOC Lambda AssumeRole 관련 변수
# ============================================================

variable "soc_lambda_role_name" {
  description = "SOC 계정의 Lambda 실행 Role 이름. 비어있으면 SOC 계정 root 허용 (덜 안전)."
  type        = string
  default     = ""
}