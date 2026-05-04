# 1. DB 서브넷 그룹 (2a, 2c 서브넷 포함)
resource "aws_db_subnet_group" "this" {
  name       = "fin-${var.env_name}-db-group"
  subnet_ids = var.db_subnet_ids
  tags       = { Name = "fin-${var.env_name}-db-group" }
}

# 2. RDS 인스턴스 생성
resource "aws_db_instance" "this" {
  identifier           = "fin-${var.env_name}-db"
  allocated_storage    = 20
  storage_type         = "gp3"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"
  
  # DB 접속 정보 (변수화 권장)
  db_name              = "joa"
  username             = "admin"
  # Secrets Manager에서 생성된 값을 참조
  password = aws_secretsmanager_secret_version.db_password.secret_string
  
  # 중요: 사용자님의 변수에 따라 Multi-AZ 결정
  multi_az             = var.is_prod_deployment
  
  db_subnet_group_name = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.db_sg_id]
  
  skip_final_snapshot  = true
  publicly_accessible  = false # 보안을 위해 외부 접속 차단

  storage_encrypted = true
  kms_key_id        = aws_kms_key.rds.arn
}