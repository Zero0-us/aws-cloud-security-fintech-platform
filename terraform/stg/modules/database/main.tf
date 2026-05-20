resource "aws_db_subnet_group" "this" {
  name       = "fin-${var.env_name}-db-group"
  subnet_ids = var.db_subnet_ids

  tags = {
    Name = "fin-${var.env_name}-db-group"
  }
}

resource "aws_db_instance" "this" {
  identifier        = "fin-${var.env_name}-db"
  allocated_storage = 20
  storage_type      = "gp3"
  engine            = "postgres"
  engine_version    = "16"
  instance_class    = "db.t3.micro"

  db_name  = "vulnerable_bank"
  username = "postgres"
  password = aws_secretsmanager_secret_version.db_password.secret_string
  port     = 5432

  multi_az               = var.is_prod_deployment
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.db_sg_id]

  publicly_accessible = false
  skip_final_snapshot = true

  storage_encrypted = true
  kms_key_id        = aws_kms_key.rds.arn

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  tags = {
    Name    = "fin-${var.env_name}-db"
    Service = "vuln-bank"
    Engine  = "postgresql"
  }
}
