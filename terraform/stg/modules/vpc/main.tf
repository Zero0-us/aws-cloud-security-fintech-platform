resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  tags                 = { Name = "fin-${var.env_name}-vpc" }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "fin-${var.env_name}-igw" }
}

resource "aws_subnet" "public" {
  count             = length(var.public_subnets)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.public_subnets[count.index]
  availability_zone = var.azs[count.index]
  tags = {
    Name                                = "fin-${var.env_name}-pub-sub-${substr(var.azs[count.index], -2, 2)}"
    "kubernetes.io/cluster/fin-stg-eks" = "shared"
    "kubernetes.io/role/elb"            = "1"
  }
}

resource "aws_subnet" "private" {
  count             = length(var.private_subnets)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = var.azs[count.index]
  tags = {
    Name                                = "fin-${var.env_name}-pri-sub-${substr(var.azs[count.index], -2, 2)}"
    "kubernetes.io/cluster/fin-stg-eks" = "shared" # EKS 클러스터 이름과 동일하게 매핑
    "kubernetes.io/role/internal-elb"   = "1"
  }
}

resource "aws_subnet" "db" {
  count             = length(var.db_subnets)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.db_subnets[count.index]
  availability_zone = var.azs[count.index]
  tags              = { Name = "fin-${var.env_name}-db-sub-${substr(var.azs[count.index], -2, 2)}" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = { Name = "fin-${var.env_name}-pub-rt" }
}

resource "aws_route_table_association" "public" {
  count          = length(var.public_subnets)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "fin-${var.env_name}-pri-rt" }
}

resource "aws_route_table_association" "private" {
  count          = length(var.private_subnets)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table" "db" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "fin-${var.env_name}-db-rt" }
}

resource "aws_route_table_association" "db" {
  count          = length(var.db_subnets)
  subnet_id      = aws_subnet.db[count.index].id
  route_table_id = aws_route_table.db.id
}

# [비용 최적화] NAT Gateway 1개만 생성하여 첫 번째 Public 서브넷에 배치 ↓
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "fin-${var.env_name}-nat-eip" }
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  tags          = { Name = "fin-${var.env_name}-nat-2a" }
  depends_on    = [aws_internet_gateway.this]
}

resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this.id
}