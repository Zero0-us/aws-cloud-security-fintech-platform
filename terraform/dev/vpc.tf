# ============================================================
# vpc.tf — VPC + 서브넷 + IGW + NAT + 라우팅
# ============================================================
# 네트워크의 모든 것을 정의하는 파일.
# 아키텍처에서 "fin-dev-vpc (10.30.0.0/16)" 박스 전체에 해당.

# ────────────────────────────────────────────
# 1. VPC 생성
# ────────────────────────────────────────────
# VPC = Virtual Private Cloud, AWS 안에서 너만의 가상 네트워크.
# 10.30.0.0/16 = 10.30.0.0 ~ 10.30.255.255 (65,536개 IP)
# Dev 전용 CIDR. Security=10.10, Prod=10.20과 겹치지 않음.

resource "aws_vpc" "dev" {
  cidr_block           = "10.30.0.0/16"
  enable_dns_support   = true    # VPC 내부 DNS 해석 활성화 (EKS 필수)
  enable_dns_hostnames = true    # EC2에 DNS 호스트명 부여 (EKS 필수)

  tags = {
    Name = "fin-dev-vpc"
  }
}

# ────────────────────────────────────────────
# 2. 서브넷 6개 생성 (3계층 × 2 AZ)
# ────────────────────────────────────────────
# 3계층 망분리: Public(DMZ) → Private(App) → DB(Data)
# 2개 AZ: ap-northeast-2a, ap-northeast-2c (고가용성)
#
# 금융 보안 규정(전자금융감독규정 제15조)상
# "정보처리시스템은 네트워크를 분리하여야 한다"
# → Public: 외부 접점(ALB), Private: 앱 서버, DB: 데이터베이스

# === Public 서브넷 (초록색 — 인터넷 직접 통신 가능) ===
# ALB와 NAT Gateway가 여기 들어감

resource "aws_subnet" "dev_pub_2a" {
  vpc_id                  = aws_vpc.dev.id
  cidr_block              = "10.30.1.0/24"       # 254개 IP (호스트용)
  availability_zone       = "ap-northeast-2a"
  map_public_ip_on_launch = true                  # 여기 생성된 리소스에 공인 IP 자동 부여

  tags = {
    Name = "fin-dev-pub-sub-2a"
    # EKS가 이 서브넷에 ALB를 만들 수 있도록 태그 필수
    "kubernetes.io/role/elb" = "1"
    "kubernetes.io/cluster/fin-dev-eks" = "shared"
  }
}

resource "aws_subnet" "dev_pub_2c" {
  vpc_id                  = aws_vpc.dev.id
  cidr_block              = "10.30.2.0/24"
  availability_zone       = "ap-northeast-2c"
  map_public_ip_on_launch = true

  tags = {
    Name = "fin-dev-pub-sub-2c"
    "kubernetes.io/role/elb" = "1"
    "kubernetes.io/cluster/fin-dev-eks" = "shared"
  }
}

# === Private 서브넷 (파란색 — EKS 노드가 들어감) ===
# 인터넷에서 직접 접근 불가. NAT Gateway를 통해서만 외부 통신.

resource "aws_subnet" "dev_pri_2a" {
  vpc_id            = aws_vpc.dev.id
  cidr_block        = "10.30.10.0/24"
  availability_zone = "ap-northeast-2a"

  tags = {
    Name = "fin-dev-pri-sub-2a"
    # EKS 내부 로드밸런서용 태그
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/fin-dev-eks" = "shared"
  }
}

resource "aws_subnet" "dev_pri_2c" {
  vpc_id            = aws_vpc.dev.id
  cidr_block        = "10.30.11.0/24"
  availability_zone = "ap-northeast-2c"

  tags = {
    Name = "fin-dev-pri-sub-2c"
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/fin-dev-eks" = "shared"
  }
}

# === DB 서브넷 (파란색 — RDS만 들어감) ===
# 가장 안쪽 계층. EKS 노드에서만 5432 포트로 접근 가능.
# 인터넷은 물론, Public 서브넷에서도 직접 접근 불가.

resource "aws_subnet" "dev_db_2a" {
  vpc_id            = aws_vpc.dev.id
  cidr_block        = "10.30.20.0/24"
  availability_zone = "ap-northeast-2a"

  tags = {
    Name = "fin-dev-db-sub-2a"
  }
}

resource "aws_subnet" "dev_db_2c" {
  vpc_id            = aws_vpc.dev.id
  cidr_block        = "10.30.21.0/24"
  availability_zone = "ap-northeast-2c"

  tags = {
    Name = "fin-dev-db-sub-2c"
  }
}

# ────────────────────────────────────────────
# 3. Internet Gateway
# ────────────────────────────────────────────
# VPC ↔ 인터넷 연결 관문.
# 이게 없으면 VPC는 완전히 고립된 네트워크.
# Public 서브넷의 리소스(ALB)가 인터넷과 통신하려면 필수.

resource "aws_internet_gateway" "dev" {
  vpc_id = aws_vpc.dev.id

  tags = {
    Name = "fin-dev-igw"
  }
}

# ────────────────────────────────────────────
# 4. Elastic IP + NAT Gateway
# ────────────────────────────────────────────
# NAT Gateway = Private 서브넷 → 인터넷 단방향 통로.
# EKS 노드가 Docker 이미지 pull, OS 패치 등을 하려면 필요.
# 들어오는 건 차단, 나가는 것만 허용 → 보안!
#
# ⚠️ NAT Gateway는 $32/월. 실습 끝나면 바로 삭제할 것!
# EIP(탄력적 IP)는 NAT Gateway에 붙는 고정 공인 IP.

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "fin-dev-natgw-eip"
  }
}

resource "aws_nat_gateway" "dev" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.dev_pub_2a.id   # Public 서브넷에 배치해야 함!

  tags = {
    Name = "fin-dev-natgw"
  }

  # IGW가 먼저 있어야 NAT Gateway가 작동
  depends_on = [aws_internet_gateway.dev]
}

# ────────────────────────────────────────────
# 5. 라우팅 테이블
# ────────────────────────────────────────────
# "이 IP 대역으로 가는 트래픽은 어디로 보낼까?" 규칙표.
# VPC 내부(10.30.0.0/16)는 자동으로 local 라우팅됨.
# 그 외(0.0.0.0/0)를 어디로 보내느냐가 Public vs Private의 차이.

# === Public 라우팅 테이블 ===
# 0.0.0.0/0 → IGW (인터넷 직접 통신)

resource "aws_route_table" "pub" {
  vpc_id = aws_vpc.dev.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dev.id   # 인터넷 직행!
  }

  tags = {
    Name = "fin-dev-pub-rt"
  }
}

# Public 서브넷 2개를 이 라우팅 테이블에 연결
resource "aws_route_table_association" "pub_2a" {
  subnet_id      = aws_subnet.dev_pub_2a.id
  route_table_id = aws_route_table.pub.id
}

resource "aws_route_table_association" "pub_2c" {
  subnet_id      = aws_subnet.dev_pub_2c.id
  route_table_id = aws_route_table.pub.id
}

# === Private 라우팅 테이블 ===
# 0.0.0.0/0 → NAT Gateway (인터넷은 NAT 경유, 외부에서 직접 접근 불가)

resource "aws_route_table" "pri" {
  vpc_id = aws_vpc.dev.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.dev.id   # NAT 경유!
  }

  tags = {
    Name = "fin-dev-pri-rt"
  }
}

# Private 서브넷 2개를 이 라우팅 테이블에 연결
resource "aws_route_table_association" "pri_2a" {
  subnet_id      = aws_subnet.dev_pri_2a.id
  route_table_id = aws_route_table.pri.id
}

resource "aws_route_table_association" "pri_2c" {
  subnet_id      = aws_subnet.dev_pri_2c.id
  route_table_id = aws_route_table.pri.id
}

# === DB 전용 라우팅 테이블 (엑셀: fin-dev-db-rt) ===
# DB 서브넷은 VPC 내부 통신만 허용 (인터넷 라우팅 없음!).
# 0.0.0.0/0 라우트가 없음 → NAT Gateway조차 사용 불가 → 완전 격리.
# Private RT와 분리하는 이유:
#   - DB는 외부 통신이 전혀 필요 없음
#   - 혹시 모를 아웃바운드 데이터 유출도 라우팅 레벨에서 차단
#   - 금융 규정상 DB 계층 격리 강화 목적

resource "aws_route_table" "db" {
  vpc_id = aws_vpc.dev.id

  # 0.0.0.0/0 라우트 없음! local(10.30.0.0/16)만 자동 라우팅.
  # → DB는 VPC 내부에서만 통신 가능.

  tags = {
    Name = "fin-dev-db-rt"
  }
}

# DB 서브넷 2개를 DB 전용 라우팅 테이블에 연결
resource "aws_route_table_association" "db_2a" {
  subnet_id      = aws_subnet.dev_db_2a.id
  route_table_id = aws_route_table.db.id
}

resource "aws_route_table_association" "db_2c" {
  subnet_id      = aws_subnet.dev_db_2c.id
  route_table_id = aws_route_table.db.id
}
