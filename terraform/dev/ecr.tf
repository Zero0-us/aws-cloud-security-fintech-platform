resource "aws_ecr_repository" "vuln_bank" {
  name                 = "vuln-bank-dev"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = "vuln-bank-dev"
  }
}

resource "aws_ecr_lifecycle_policy" "vuln_bank" {
  repository = aws_ecr_repository.vuln_bank.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 5 dev images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 5
      }
      action = { type = "expire" }
    }]
  })
}
