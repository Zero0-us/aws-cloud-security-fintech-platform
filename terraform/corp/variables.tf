# 기본 설정
variable "aws_profile" {
  description = "AWS CLI 프로필 명칭"
  type        = string
  default     = "fintech-corp"
}

variable "region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "env_name" {
  description = "환경 구분"
  type        = string
  default     = "corp"
}

# VPC 설정
variable "vpc_cidr" {
  description = "Corp VPC CIDR 대역"
  type        = string
  default     = "192.168.0.0/16"
}

variable "availability_zones" {
  description = "가용 영역"
  type        = list(string)
  default     = ["ap-northeast-2a", "ap-northeast-2c"]
}

variable "public_subnets" {
  description = "Public 서브넷 CIDR 대역"
  type        = list(string)
  default     = ["192.168.1.0/24", "192.168.2.0/24"]
}

# Corp VPN EIP (콘솔에서 수동 생성 후 Allocation ID 입력)
variable "corp_eip_allocation_id" {
  description = "Corp VPN EC2에 붙일 EIP Allocation ID (콘솔에서 수동 생성)"
  type        = string
  default     = "eipalloc-0d4cb1fb12578c283"
}

# VPN 설정 (팀원으로부터 받을 정보)
variable "target_accounts" {
  description = "Target Account VPN 정보 (팀원이 제공)"
  type = map(object({
    account_id = string
    vpc_cidr   = string
    eip        = string  # 상대방 VPN EIP (팀원 전달값)
    psk        = string  # 사전 합의한 PSK
  }))
  default = {
    prod = {
      account_id = ""
      vpc_cidr   = "10.20.0.0/16"
      eip        = ""
      psk        = "mK9vR2pL8wQ4nX7yA1jF6tE3sZcB0dGh"
    }
    staging = {
      account_id = ""
      vpc_cidr   = "10.40.0.0/16"
      eip        = ""
      psk        = "Tz5nB8yRmK2wQ6vA1jL9sE4cF7hG0dIu"
    }
    dev = {
      account_id = "364585378962"
      vpc_cidr   = "10.30.0.0/16"
      eip        = ""
      psk        = "gXDA4aP93u5bNTcOSPEQ5albxqGhXZQX"
    }
    soc = {
      account_id = ""
      vpc_cidr   = "10.10.0.0/16"
      eip        = ""
      psk        = "Xp3vL4mQ7nB2wK6yA1jF8tE9sZ+cG0dR"
    }
  }
}
