variable "aws_profile" {
  description = "로컬 환경의 IAM 자격 증명을 특정하기 위한 AWS CLI 프로필 명칭"
  type        = string
  default     = "Lee-role"
}

variable "region" {
  description = "지연 시간 최적화 및 법규 준수를 위한 리소스 배포 대상 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "env_name" {
  description = "리소스 명명 규칙(Naming Convention) 및 환경별 설정 분리를 위한 식별자"
  type        = string
  default     = "prod"
}

variable "is_prod_deployment" {
  description = "Prod 환경 RDS Multi-AZ 활성화. 고가용성 보장을 위해 true 설정."
  type        = bool
  default     = true
}

variable "vpc_cidr" {
  description = "VPC 전체 가용 아이피 대역 정의"
  type        = string
  default     = "10.20.0.0/16"
}

variable "availability_zones" {
  description = "서비스 고가용성 보장을 위한 물리적 데이터 센터 분산 배치 기준"
  type        = list(string)
  default     = ["ap-northeast-2a", "ap-northeast-2c"]
}

variable "public_subnets" {
  description = "외부 트래픽 수용(ALB, NAT GW)을 위한 공개 주소 대역"
  type        = list(string)
  default     = ["10.20.1.0/24", "10.20.2.0/24"]
}

variable "private_subnets" {
  description = "내부 비즈니스 로직(App, EKS Nodes) 보호를 위한 비공개 주소 대역"
  type        = list(string)
  default     = ["10.20.10.0/24", "10.20.11.0/24"]
}

variable "db_subnets" {
  description = "데이터 보호를 위해 외부 및 애플리케이션 계층으로부터 격리된 DB 전용 대역"
  type        = list(string)
  default     = ["10.20.20.0/24", "10.20.21.0/24"]
}

variable "node_group_name" {
  description = "EKS 노드 그룹 이름"
  type        = string
  default     = "fin-prod-nodegroup"
}

variable "eks_access_entries" {
  description = "EKS 클러스터 권한 명단"
  type        = any
  default     = {}
}

variable "corp_account_id" {
  description = "Corp AWS 계정 ID (IAM Role 신뢰 주체)"
  type        = string
  default     = ""
}