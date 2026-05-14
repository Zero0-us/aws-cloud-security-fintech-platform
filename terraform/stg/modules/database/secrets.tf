# 1. 임의의 강력한 비밀번호 생성
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# 2. Secrets Manager에 비밀 저장소 생성
resource "aws_secretsmanager_secret" "db_password" {
  name = "fin-${var.env_name}-db-password-v2"
  # KMS 키를 사용하여 암호화 (이미 만든 fin-rds-cmk 활용 가능)
  kms_key_id = aws_kms_key.rds.arn
  # destroy 시 7일 대기 없이 즉시 영구 삭제를 시도함
  recovery_window_in_days = 0
}

# 3. 생성된 비밀번호를 저장소에 기록
resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db_password.result
}