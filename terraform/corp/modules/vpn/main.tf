data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

data "aws_eip" "corp_vpn" {
  id = var.corp_eip_allocation_id
}

resource "aws_security_group" "vpn" {
  name        = "fin-${var.env_name}-vpn-sg"
  description = "strongSwan VPN EC2 Security Group"
  vpc_id      = var.vpc_id

  ingress {
    description = "IKE"
    from_port   = 500
    to_port     = 500
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "NAT-T"
    from_port   = 4500
    to_port     = 4500
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "fin-${var.env_name}-vpn-sg" }
}

resource "aws_iam_role" "vpn_ssm" {
  name = "fin-${var.env_name}-vpn-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "vpn_ssm" {
  role       = aws_iam_role.vpn_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "vpn_ssm" {
  name = "fin-${var.env_name}-vpn-ssm-profile"
  role = aws_iam_role.vpn_ssm.name
}

resource "aws_instance" "vpn" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = "t3.micro"
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [aws_security_group.vpn.id]
  source_dest_check      = false
  iam_instance_profile   = aws_iam_instance_profile.vpn_ssm.name

  user_data = templatefile("${path.module}/user_data.sh.tpl", {
    corp_eip        = data.aws_eip.corp_vpn.public_ip
    corp_vpc_cidr   = var.vpc_cidr
    target_accounts = var.target_accounts
  })

  tags = { Name = "fin-${var.env_name}-vpn-ec2" }
}

resource "aws_eip_association" "vpn" {
  instance_id   = aws_instance.vpn.id
  allocation_id = var.corp_eip_allocation_id
}

resource "aws_route" "vpn_targets" {
  for_each = var.target_accounts

  route_table_id         = var.public_route_table_id
  destination_cidr_block = each.value.vpc_cidr
  network_interface_id   = aws_instance.vpn.primary_network_interface_id

  depends_on = [aws_instance.vpn]
}
