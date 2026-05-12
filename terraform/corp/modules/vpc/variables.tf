variable "env_name" {
  description = "환경 이름"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR 대역"
  type        = string
}

variable "availability_zones" {
  description = "가용 영역 리스트"
  type        = list(string)
}

variable "public_subnets" {
  description = "Public 서브넷 CIDR 리스트"
  type        = list(string)
}
