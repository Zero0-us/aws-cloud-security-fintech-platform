## [Variables] 서비스 확장성을 고려한 리포지토리 목록 정의
## Input: 서비스 명칭 리스트 (String)
## Output: 서비스별 독립적인 ECR 리포지토리 리소스 생성

variable "service_names" {
  description = "ECR 리포지토리를 생성할 마이크로서비스 식별자 목록"
  type        = list(string)
  default     = ["account-service", "auth-service", "payment-service", "transfer-service"]
}

  # 1. AWS ECR Repository 생성
resource "aws_ecr_repository" "services" {
  for_each             = toset(var.service_names)
  name                 = each.key

  # 빌드 파이프라인에서 동일 태그(예: latest)를 재사용하는 관행을 고려해 MUTABLE 유지
  # FIXME: 향후 배포 안정성을 위해 IMMUTABLE로 전환하고 태그에 커밋 해시 사용 권장
  image_tag_mutability = "MUTABLE"

  # [보안] 핀테크 보안 규정: 이미지 푸시 시 자동 취약점 스캔
  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS" # 기본 AES256보다 보안이 강화된 KMS 암호화 권장
  }
}

## 2. ECR Lifecycle Policy (비용 최적화 정책)
# 각 리포지토리당 최신 이미지 10개만 유지하고 나머지는 자동 삭제
resource "aws_ecr_lifecycle_policy" "cleanup" {
  # 생성된 리포지토리와 1:1 매핑하여 정책 적용
  for_each   = aws_ecr_repository.services
  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus     = "any"
        countType     = "imageCountMoreThan"
        countNumber   = 10
      }
      action = { type = "expire" }
    }]
  })
}