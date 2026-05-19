resource "aws_db_subnet_group" "dev" {
  name        = "fin-dev-db-subnet-group"
  description = "Dev environment DB subnet group"

  subnet_ids = [
    aws_subnet.dev_db_2a.id,
    aws_subnet.dev_db_2c.id,
  ]

  tags = {
    Name = "fin-dev-db-subnet-group"
  }
}

resource "random_password" "db_password" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db_password" {
  name                    = "fin-dev-db-password-v2"
  description             = "Dev PostgreSQL password for vuln-bank"
  recovery_window_in_days = 0

  tags = {
    Name = "fin-dev-db-password-v2"
  }
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db_password.result
}

resource "aws_db_instance" "dev" {
  identifier = "fin-dev-db"

  engine         = "postgres"
  engine_version = "16"
  instance_class = "db.t3.micro"

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = "vulnerable_bank"
  username = "postgres"
  password = random_password.db_password.result
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.dev.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  multi_az                = false
  backup_retention_period = 1
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  deletion_protection = false
  skip_final_snapshot = true

  tags = {
    Name = "fin-dev-db"
  }
}
