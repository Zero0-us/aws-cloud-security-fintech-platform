# ============================================================
# rds.tf — RDS MySQL 8.0 (프리티어)
# ============================================================
# RDS = Relational Database Service
# AWS가 DB 서버를 관리해줌 (패치, 백업, 장애 복구 자동).
# 아키텍처에서 db-sub-2a에 있는 보라색 RDS 아이콘에 해당.
#
# 엑셀 기준: MySQL 8.0, db.t3.micro, 20GB GP3, Single-AZ
# Dev 환경이라 Multi-AZ 없음.
# db.t3.micro = 프리티어 무료 (12개월 750hr/월).

# ────────────────────────────────────────────
# 1. DB 서브넷 그룹
# ────────────────────────────────────────────
# RDS 생성 시 "어느 서브넷에 배치할지" 지정하는 그룹.
# 최소 2개 AZ의 서브넷이 필요 (AWS 요구사항).
# 실제 Dev는 2a에만 배치되지만, 그룹 자체는 2개 AZ 필수.

resource "aws_db_subnet_group" "dev" {
  name        = "fin-dev-db-subnet-group"
  description = "Dev environment DB subnet group"

  subnet_ids = [
    aws_subnet.dev_db_2a.id,   # 10.30.20.0/24
    aws_subnet.dev_db_2c.id,   # 10.30.21.0/24
  ]

  tags = {
    Name = "fin-dev-db-subnet-group"
  }
}

# ────────────────────────────────────────────
# 2. RDS MySQL 인스턴스
# ────────────────────────────────────────────
# MySQL 8.0 선택 (엑셀 기준)

resource "aws_db_instance" "dev" {
  identifier = "fin-dev-db"

  # 엔진 설정 — MySQL 8.0 (엑셀 기준)
  engine         = "mysql"
  engine_version = "8.0"

  # 인스턴스 클래스 (프리티어!)
  # db.t3.micro = 1 vCPU, 1GB RAM
  # 프리티어: 750시간/월 무료 (12개월)
  instance_class = "db.t3.micro"

  # 스토리지 — GP3 (엑셀 기준)
  allocated_storage = 20          # 20GB (프리티어 한도)
  storage_type      = "gp3"       # General Purpose SSD v3 (엑셀 기준)
  storage_encrypted = true        # ⭐ 저장 시 암호화 (AES-256)

  # 데이터베이스 설정
  db_name  = "fintech_db"
  username = "fintech"
  password = "DevDB2026!Secure"   # ⚠️ 실제 운영에선 Secrets Manager 사용!
  port     = 3306                 # MySQL 기본 포트

  # 네트워크 설정
  db_subnet_group_name   = aws_db_subnet_group.dev.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false   # ⭐ 퍼블릭 접근 차단! (Private 서브넷이니까)

  # 가용성 설정
  multi_az = false   # Dev는 Single-AZ (비용 절감)

  # 백업 설정
  backup_retention_period = 1     # 프리티어 제한: 최대 1일
  backup_window           = "03:00-04:00"   # UTC 03시 (한국 12시)
  maintenance_window      = "Mon:04:00-Mon:05:00"

  # 삭제 보호 (실습이라 끔)
  deletion_protection = false
  skip_final_snapshot = true      # 삭제 시 최종 스냅샷 건너뜀

  tags = {
    Name = "fin-dev-db"
  }
}
