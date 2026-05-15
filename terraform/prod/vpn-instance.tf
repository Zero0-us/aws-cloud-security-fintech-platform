# ============================================================
# vpn-instance.tf — Corp 연결용 VPN EC2 (고정 IP)
# ============================================================
#
# 구성 목적:
# - Corp ↔ AWS VPC 간 VPN 연결용 EC2 생성
# - Elastic IP를 할당해 고정 공인 IP 제공
# - SSM으로 SSH 없이 접속 가능
# - Libreswan 설치 및 IP Forwarding 활성화
#
# 사용 전제:
# - module.prod_vpc 에서 아래 output 이 이미 노출되어 있어야 함
#   * vpc_id
#   * first_public_subnet_id
#   * private_route_table_id
#   * db_route_table_id
#
# 연결 절차 예시:
#   1. terraform apply 후 vpn_fixed_ip 출력값 확인
#   2. Corp 측에 고정 IP 전달
#   3. Corp 측 VPN 게이트웨이 IP, PSK 수령
#   4. SSM 접속 후 /etc/ipsec.d/* 설정
#   5. ipsec 서비스 시작 및 상태 확인
#
# ============================================================

# ============================================================
# 1. VPN 인스턴스용 보안 그룹
# ============================================================
resource "aws_security_group" "vpn" {
  name        = "fin-prod-vpn-sg"
  description = "Security group for VPN instance"
  vpc_id      = module.prod_vpc.vpc_id

  # IKE (UDP 500)
  ingress {
    from_port   = 500
    to_port     = 500
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "IKE"
  }

  # NAT-T (UDP 4500)
  ingress {
    from_port   = 4500
    to_port     = 4500
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "NAT-T"
  }

  # ESP (IP Protocol 50)
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "50"
    cidr_blocks = ["0.0.0.0/0"]
    description = "ESP"
  }

  # Corp 대역 허용
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["192.168.0.0/16"]
    description = "From Corp network"
  }

  # 내부 VPC 대역 허용
  # 실제 VPC CIDR 과 다르면 반드시 수정
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.20.0.0/16"]
    description = "From internal VPC"
  }

  # SSH (비상용)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH"
  }

  # ICMP (테스트용)
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "ICMP"
  }

  # 아웃바운드 전체 허용
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "fin-prod-vpn-sg"
  }
}

# ============================================================
# 2. VPN용 Elastic IP
# ============================================================
resource "aws_eip" "vpn" {
  domain = "vpc"

  tags = {
    Name = "fin-prod-vpn-eip"
  }
}

# ============================================================
# 3. Amazon Linux 2023 AMI 조회
# ============================================================
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ============================================================
# 4. SSM용 IAM Role
# ============================================================
resource "aws_iam_role" "vpn_ssm" {
  name = "fin-prod-vpn-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "fin-prod-vpn-ssm-role"
  }
}

resource "aws_iam_role_policy_attachment" "vpn_ssm" {
  role       = aws_iam_role.vpn_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "vpn_ssm" {
  name = "fin-prod-vpn-ssm-profile"
  role = aws_iam_role.vpn_ssm.name
}

# ============================================================
# 5. VPN EC2 인스턴스
# ============================================================
resource "aws_instance" "vpn" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.micro"
  subnet_id                   = module.prod_vpc.first_public_subnet_id
  vpc_security_group_ids      = [aws_security_group.vpn.id]
  associate_public_ip_address = false
  source_dest_check           = false
  iam_instance_profile        = aws_iam_instance_profile.vpn_ssm.name

  user_data = <<-EOF
    #!/bin/bash
    set -e

    # --------------------------------------------------------
    # SSM Agent 설치 및 활성화
    # --------------------------------------------------------
    dnf install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
    systemctl enable amazon-ssm-agent
    systemctl start amazon-ssm-agent

    # --------------------------------------------------------
    # Libreswan 설치
    # --------------------------------------------------------
    dnf install -y libreswan
    systemctl enable ipsec

    # --------------------------------------------------------
    # IP Forwarding 활성화
    # --------------------------------------------------------
    cat <<SYSCTL_EOF >> /etc/sysctl.conf
    net.ipv4.ip_forward = 1
    net.ipv4.conf.all.accept_redirects = 0
    net.ipv4.conf.all.send_redirects = 0
    SYSCTL_EOF

    sysctl -p
  EOF

  tags = {
    Name = "fin-prod-vpn-ec2"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

# ============================================================
# 6. EIP 연결
# ============================================================
resource "aws_eip_association" "vpn" {
  instance_id   = aws_instance.vpn.id
  allocation_id = aws_eip.vpn.id
}

# ============================================================
# 7. Corp 대역 라우팅 - Private RT
# ============================================================
resource "aws_route" "to_corp_pri" {
  route_table_id         = module.prod_vpc.private_route_table_id
  destination_cidr_block = "192.168.0.0/16"
  network_interface_id   = aws_instance.vpn.primary_network_interface_id
}

# ============================================================
# 8. Corp 대역 라우팅 - DB RT
# ============================================================
resource "aws_route" "to_corp_db" {
  route_table_id         = module.prod_vpc.db_route_table_id
  destination_cidr_block = "192.168.0.0/16"
  network_interface_id   = aws_instance.vpn.primary_network_interface_id
}
