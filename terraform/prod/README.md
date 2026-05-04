# Prod 환경 — AWS Cloud Security Fintech Platform

JOA OpenAPI(오픈뱅킹) 기반 핀테크 서비스를 AWS EKS 위에 배포하는 프로덕션 환경입니다.

> **원본**: [rheeeuro/joa-openapi](https://github.com/rheeeuro/joa-openapi) (SSAFY 10기 프로젝트) — 원작자 사용 허락 완료

## 아키텍처

```
Internet
  │
  ▼
Route 53 (도메인) ──→ WAF (OWASP 방어)
  │
  ▼
ALB (fin-prod-alb) ── HTTP :80
  │  Path 기반 라우팅
  │
  ├─ /              → bank-web         :3000  (뱅킹 웹)
  ├─ /admin         → admin-frontend   :3000  (관리자 대시보드)
  ├─ /docs          → docs-frontend    :3000  (API 문서 - Swagger UI)
  ├─ /v1/*          → openapi-backend  :8080  (오픈뱅킹 API)
  ├─ /member/*      → bank-backend     :8080  (회원 서비스)
  └─ /admin/api/*   → admin-backend    :8080  (관리자 API)
  │
  ▼
EKS Cluster (fin-prod-eks, K8s 1.29)
  ├─ Private Subnet 2a (10.20.10.0/24)
  └─ Private Subnet 2c (10.20.11.0/24)
  │
  ▼
RDS MySQL 8.0 (fin-prod-db, Multi-AZ)
  ├─ DB Subnet 2a (10.20.20.0/24)
  └─ DB Subnet 2c (10.20.21.0/24)
```

## 서비스 구성

| 서비스 | 기술 스택 | 포트 | 설명 |
|--------|----------|------|------|
| **bank-backend** | Spring Boot 3.2 + JPA | 8080 | 회원 가입/로그인/로그아웃, 이메일 인증 |
| **openapi-backend** | Spring Boot 3.2 + JPA | 8080 | 계좌 CRUD, 거래내역, 송금, 금융상품, 은행 관리 |
| **admin-backend** | Spring Boot 3.2 + QueryDSL | 8080 | 관리자 대시보드 API, JWT 인증 |
| **admin-frontend** | Next.js 15 + Tailwind + Flowbite | 3000 | 관리자 대시보드 웹 UI |
| **bank-web** | Next.js 14 + Tailwind | 3000 | 모바일 뱅킹 웹 (React Native에서 변환) |
| **docs-frontend** | Swagger UI | 3000 | OpenAPI 3.0 문서 자동 생성 |
| **redis** | Redis 7 Alpine | 6379 | 세션/캐시 |

## 디렉터리 구조

```
terraform/prod/
├── main.tf                          # 루트 모듈 (모듈 호출 + Helm ALB Controller)
├── providers.tf                     # AWS, Kubernetes, Helm 프로바이더
├── variables.tf                     # 변수 정의
├── vpc_peering.tf                   # Prod ↔ Audit VPC 피어링
│
├── modules/
│   ├── vpc/                         # VPC, Subnet(3계층), IGW, NAT GW, Route Table
│   ├── security/                    # Security Groups (ALB, App, DB)
│   ├── database/                    # RDS MySQL, KMS (fin-rds-cmk), Secrets Manager
│   ├── eks/                         # EKS Cluster, NodeGroup, KMS (fin-eks-cmk), ECR, IRSA
│   └── alb/                         # ALB, Target Group, Listener
│
└── services/
    ├── configmap.yaml               # 공통 환경 설정 (DB_HOST, REDIS 등)
    ├── secrets.yaml                 # 민감 정보 (DB 비밀번호, JWT 키 등)
    ├── ingress.yaml                 # ALB Ingress (7개 Path 라우팅)
    ├── redis.yaml                   # Redis Deployment + Service
    ├── db-init.sql                  # JOA DB 스키마 (8 테이블)
    │
    ├── bank-backend/                # Dockerfile + deployment.yaml
    ├── openapi-backend/             # Dockerfile + deployment.yaml
    ├── admin-backend/               # Dockerfile + deployment.yaml
    ├── admin-frontend/              # Dockerfile + deployment.yaml
    ├── bank-web/                    # Dockerfile + deployment.yaml + Next.js 소스
    │   └── app/                     # Next.js 14 App Router (63 파일)
    └── docs-frontend/               # Dockerfile + deployment.yaml (Swagger UI)
```

## Terraform 모듈

| 모듈 | 리소스 | 보안 |
|------|--------|------|
| **vpc** | VPC `10.20.0.0/16`, Public/Private/DB Subnet × 2 AZ, IGW, NAT GW | 3계층 네트워크 분리 |
| **security** | `fin-prod-alb-sg`, `fin-prod-app-sg`, `fin-prod-db-sg` | 최소 권한 인바운드 |
| **database** | RDS MySQL 8.0 (`db.t3.micro`), Multi-AZ, Secrets Manager | KMS 암호화 (`alias/fin-rds-cmk`) |
| **eks** | EKS 1.29, NodeGroup `t3.medium×2`, ECR 6개 repo, IRSA | KMS 암호화 (`alias/fin-eks-cmk`), ECR Scan on Push |
| **alb** | ALB (internet-facing), Target Group (IP mode, :8080) | Health Check `/actuator/health` |

## 사전 요구사항

- AWS CLI (프로필: `Lee-role`)
- Terraform >= 1.6.0
- kubectl
- Docker

## 배포 절차

### 1. Terraform 인프라 배포

```bash
cd terraform/prod
terraform init
terraform plan
terraform apply
```

배포 후 kubeconfig 자동 갱신:
```bash
kubectl get nodes
```

### 2. ConfigMap / Secret 업데이트

```bash
# RDS 엔드포인트 확인
terraform output -raw rds_endpoint

# configmap.yaml의 DB_HOST를 실제 RDS 엔드포인트로 교체
# secrets.yaml의 비밀번호를 실제 값으로 교체 (base64 인코딩)
```

### 3. Docker 이미지 빌드 & ECR Push

```bash
# ECR 로그인
aws ecr get-login-password --region ap-northeast-2 --profile Lee-role \
  | docker login --username AWS --password-stdin 423401347162.dkr.ecr.ap-northeast-2.amazonaws.com

# Spring Boot 백엔드 (JOA 소스 필요)
docker build -t bank-backend:latest -f services/bank-backend/Dockerfile /path/to/joa-openapi/bank/backend
docker tag bank-backend:latest 423401347162.dkr.ecr.ap-northeast-2.amazonaws.com/bank-backend:latest
docker push 423401347162.dkr.ecr.ap-northeast-2.amazonaws.com/bank-backend:latest

# openapi-backend, admin-backend도 동일하게 진행
# Next.js 프론트엔드
docker build -t admin-frontend:latest -f services/admin-frontend/Dockerfile /path/to/joa-openapi/admin/frontend
docker tag admin-frontend:latest 423401347162.dkr.ecr.ap-northeast-2.amazonaws.com/admin-frontend:latest
docker push 423401347162.dkr.ecr.ap-northeast-2.amazonaws.com/admin-frontend:latest

# bank-web (변환된 Next.js)
docker build -t bank-web:latest services/bank-web/app/
docker tag bank-web:latest 423401347162.dkr.ecr.ap-northeast-2.amazonaws.com/bank-web:latest
docker push 423401347162.dkr.ecr.ap-northeast-2.amazonaws.com/bank-web:latest

# docs-frontend (Swagger UI)
docker build -t docs-frontend:latest services/docs-frontend/
docker tag docs-frontend:latest 423401347162.dkr.ecr.ap-northeast-2.amazonaws.com/docs-frontend:latest
docker push 423401347162.dkr.ecr.ap-northeast-2.amazonaws.com/docs-frontend:latest
```

### 4. Kubernetes 매니페스트 배포

```bash
# 순서 중요: ConfigMap/Secret → Redis → Backends → Frontends → Ingress
kubectl apply -f services/configmap.yaml
kubectl apply -f services/secrets.yaml
kubectl apply -f services/redis.yaml

kubectl apply -f services/bank-backend/deployment.yaml
kubectl apply -f services/openapi-backend/deployment.yaml
kubectl apply -f services/admin-backend/deployment.yaml
kubectl apply -f services/admin-frontend/deployment.yaml
kubectl apply -f services/bank-web/deployment.yaml
kubectl apply -f services/docs-frontend/deployment.yaml

kubectl apply -f services/ingress.yaml

# 확인
kubectl get pods
kubectl get ingress
```

## DB 스키마

`services/db-init.sql`에 JOA 8테이블 스키마 포함:

| 테이블 | 설명 |
|--------|------|
| `member` | 회원 정보 |
| `account` | 계좌 |
| `transaction` | 거래 내역 |
| `product` | 금융 상품 |
| `bank` | 은행 정보 |
| `dummy` | 더미 계좌 |
| `admin` | 관리자 |
| `api_key` | API 키 관리 |

## 보안 설계

- **네트워크 분리**: Public(ALB/NAT) → Private(EKS) → DB(RDS) 3계층
- **KMS 암호화**: EKS Secret (`fin-eks-cmk`) + RDS Storage (`fin-rds-cmk`)
- **ECR 보안**: Push 시 취약점 스캔, KMS 암호화, 최신 10개 이미지 유지
- **IRSA**: ALB Controller / EBS CSI Driver — Pod 단위 IAM 권한 분리
- **Secrets Manager**: RDS 비밀번호 자동 생성 (length=16, special=true)
- **VPC Peering**: Prod ↔ Audit 계정 간 보안 로그 전송 경로
- **EKS Logging**: API, Audit, Authenticator, ControllerManager, Scheduler 전체 활성화

## VPC Peering

| 연결 | Source | Destination |
|------|--------|-------------|
| `fin-prod-to-audit-peering` | Prod VPC (10.20.0.0/16) | Audit VPC (10.10.0.0/16, 계정 399707826519) |

⚠️ Audit 계정에서 피어링 요청 수락 필요

## 운영 참고

- `secrets.yaml`은 예시값입니다. **절대 실제 비밀번호를 Git에 커밋하지 마세요.**
- 운영 시 ALB에 HTTPS/443 + ACM 인증서 적용 권장
- ECR 이미지 태그는 `latest` 대신 커밋 해시 사용 권장
- NAT Gateway 1개 구성 (비용 절감). AZ 장애 대응 필요 시 2개로 확장

## 정리

```bash
# K8s 리소스 먼저 삭제
kubectl delete -f services/ingress.yaml
kubectl delete -f services/

# Terraform 인프라 삭제
terraform destroy
```
