# ============================================================
# vpn-instance.tf — Corp 연결용 VPN EC2 (고정 IP)
# ============================================================
#
# SOC 환경 특이사항:
#   - Private/DB Subnet 없음 (S3 중심 아키텍처)
#   - Public RT에 Corp 라우팅 추가
#   - 나중에 Peering Subnet 추가 예정
#
# ⚠️ VPN 연결 설정 방법:
#   1. terraform apply 후 vpn_fixed_ip 출력값을 Corp에 전달
#   2. Corp에서 VPN IP, PSK 전달받음
#   3. SSM 접속: aws ssm start-session --target <인스턴스ID>
#   4. Libreswan 설정:
#      - /etc/ipsec.d/corp-vpn.conf (Corp VPN IP 설정)
#      - /etc/ipsec.d/corp-vpn.secrets (PSK 설정)
#   5. sudo systemctl start ipsec
#   6. sudo ipsec status 로 연결 확인
#
# ============================================================

#============================================================
# 1. VPN 인스턴스용 보안 그룹
#============================================================
resource "aws_security_group" "vpn" {
  name        = "fin-soc-vpn-sg"
  description = "Security group for VPN instance"
  vpc_id      = aws_vpc.soc.id

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

  # ESP (Protocol 50)
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "50"
    cidr_blocks = ["0.0.0.0/0"]
    description = "ESP"
  }

  # Corp 네트워크에서 모든 트래픽 허용
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["192.168.0.0/16"]
    description = "From Corp network"
  }

  # 내부 VPC에서 모든 트래픽 허용
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.10.0.0/16"]
    description = "From internal VPC"
  }

  # SSH (관리용)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH"
  }

  # ICMP (Ping 테스트용)
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "ICMP"
  }

  # Outbound 모든 트래픽 허용
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "fin-soc-vpn-sg"
  }
}

#============================================================
# 2. VPN용 EIP (고정 IP)
#============================================================
resource "aws_eip" "vpn" {
  domain = "vpc"

  tags = {
    Name = "fin-soc-vpn-eip"
  }
}

#============================================================
# 3. Amazon Linux 2023 AMI
#============================================================
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

#============================================================
# 4. VPN EC2 인스턴스
#============================================================
resource "aws_instance" "vpn" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.soc_pub_2a.id
  vpc_security_group_ids      = [aws_security_group.vpn.id]
  associate_public_ip_address = false
  source_dest_check           = false
  iam_instance_profile        = aws_iam_instance_profile.vpn_ssm.name

  user_data = <<-EOF
    #!/bin/bash
    # SSM Agent 설치
    dnf install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
    systemctl enable amazon-ssm-agent
    systemctl start amazon-ssm-agent
    
    # Libreswan 설치
    dnf install -y libreswan
    systemctl enable ipsec
    
    # IP 포워딩 활성화
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
    echo "net.ipv4.conf.all.accept_redirects = 0" >> /etc/sysctl.conf
    echo "net.ipv4.conf.all.send_redirects = 0" >> /etc/sysctl.conf
    sysctl -p
  EOF

  tags = {
    Name = "fin-soc-vpn-ec2"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

#============================================================
# 5. EIP를 VPN 인스턴스에 연결
#============================================================
resource "aws_eip_association" "vpn" {
  instance_id   = aws_instance.vpn.id
  allocation_id = aws_eip.vpn.id
}

#============================================================
# 6. Corp 대역 라우팅 - Public RT (SOC는 Public RT에만 추가)
#============================================================
resource "aws_route" "to_corp_pub" {
  route_table_id         = aws_route_table.soc_pub.id
  destination_cidr_block = "192.168.0.0/16"
  network_interface_id   = aws_instance.vpn.primary_network_interface_id
}

#============================================================
# 7. IAM Role for SSM + S3 접근
#============================================================
resource "aws_iam_role" "vpn_ssm" {
  name = "fin-soc-vpn-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "fin-soc-vpn-ssm-role"
  }
}

resource "aws_iam_role_policy_attachment" "vpn_ssm" {
  role       = aws_iam_role.vpn_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "vpn_s3" {
  role       = aws_iam_role.vpn_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_iam_instance_profile" "vpn_ssm" {
  name = "fin-soc-vpn-ssm-profile"
  role = aws_iam_role.vpn_ssm.name
}