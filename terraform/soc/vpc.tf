#============================================================
# VPC
#============================================================
resource "aws_vpc" "soc" {
  cidr_block           = "10.10.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "fin-soc-vpc"
  }
}

#============================================================
# Internet Gateway
#============================================================
resource "aws_internet_gateway" "soc" {
  vpc_id = aws_vpc.soc.id

  tags = {
    Name = "fin-soc-igw"
  }
}

#============================================================
# Public Subnet (VPN EC2용)
#============================================================
resource "aws_subnet" "soc_pub_2a" {
  vpc_id                  = aws_vpc.soc.id
  cidr_block              = "10.10.1.0/24"
  availability_zone       = "ap-northeast-2a"
  map_public_ip_on_launch = false

  tags = {
    Name = "fin-soc-pub-sub-2a"
  }
}

resource "aws_subnet" "soc_pub_2c" {
  vpc_id                  = aws_vpc.soc.id
  cidr_block              = "10.10.2.0/24"
  availability_zone       = "ap-northeast-2c"
  map_public_ip_on_launch = false

  tags = {
    Name = "fin-soc-pub-sub-2c"
  }
}

#============================================================
# Public Route Table
#============================================================
resource "aws_route_table" "soc_pub" {
  vpc_id = aws_vpc.soc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.soc.id
  }

  tags = {
    Name = "fin-soc-pub-rt"
  }
}

resource "aws_route_table_association" "soc_pub_2a" {
  subnet_id      = aws_subnet.soc_pub_2a.id
  route_table_id = aws_route_table.soc_pub.id
}

resource "aws_route_table_association" "soc_pub_2c" {
  subnet_id      = aws_subnet.soc_pub_2c.id
  route_table_id = aws_route_table.soc_pub.id
}

#============================================================
# S3 VPC Endpoint (Gateway Type)
#============================================================
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.soc.id
  service_name      = "com.amazonaws.ap-northeast-2.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    aws_route_table.soc_pub.id
  ]

  tags = {
    Name = "fin-soc-s3-endpoint"
  }
}