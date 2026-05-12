variable "env_name" {
  description = "환경 이름"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "vpc_cidr" {
  description = "Corp VPC CIDR"
  type        = string
}

variable "public_subnet_id" {
  description = "VPN EC2를 배치할 Public 서브넷 ID"
  type        = string
}

variable "public_route_table_id" {
  description = "Public Route Table ID"
  type        = string
}

variable "corp_eip_allocation_id" {
  description = "Corp VPN EC2에 붙일 EIP Allocation ID"
  type        = string
}

variable "target_accounts" {
  description = "VPN 연결 대상 계정 정보"
  type = map(object({
    account_id = string
    vpc_cidr   = string
    eip        = string
    psk        = string
  }))
}
