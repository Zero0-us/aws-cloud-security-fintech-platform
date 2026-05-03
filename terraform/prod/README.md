# AWS Cloud Security Fintech Platform

Terraform으로 AWS 기반 핀테크 서비스 인프라를 구성하고, EKS 위에 인증, 계좌, 결제, 송금 마이크로서비스를 배포하는 클라우드 보안 프로젝트입니다.

금융 서비스 환경에서 중요한 네트워크 분리, 최소 권한, 데이터 암호화, 컨테이너 이미지 보안, 감사 로그, 이상 거래 탐지 흐름을 인프라와 애플리케이션 레벨에서 함께 다룹니다.

## 주요 기능

- VPC 3계층 분리: Public, Private, DB 서브넷을 분리하고 2개 AZ에 배치
- EKS 기반 컨테이너 실행 환경: Private Subnet에 노드 그룹 구성
- ALB 구성: Public Subnet에 Application Load Balancer 배치
- RDS MySQL 구성: DB Subnet에 외부 비공개 데이터베이스 생성
- KMS 암호화: RDS 스토리지 및 EKS Secret 암호화 적용
- Secrets Manager: DB 패스워드 자동 생성 및 보관
- ECR 보안: 서비스별 이미지 저장소, KMS 암호화, Push 시 취약점 스캔
- IRSA 적용: AWS Load Balancer Controller, EBS CSI Driver에 IAM Role for Service Account 구성
- 마이크로서비스 API: Auth, Account, Payment, Transfer 서비스 제공
- 금융 보안 로직: MFA, JWT, 계좌번호 마스킹, AES-256-GCM 암호화, 멱등성, 일일 한도, FDS

## 아키텍처

```text
Internet
   |
   v
Application Load Balancer
   |
   v
EKS Cluster - Private Subnets
   |
   +-- auth-service
   +-- account-service
   +-- payment-service
   +-- transfer-service
   |
   v
RDS MySQL - DB Subnets

EKS workloads use ECR images.
RDS and EKS secrets are protected with KMS.
DB credentials are managed by Secrets Manager.
```

## 디렉터리 구조

```text
.
├── main.tf
├── providers.tf
├── variables.tf
├── terraform.tfvars
├── modules
│   ├── alb
│   ├── database
│   ├── eks
│   ├── security
│   └── vpc
└── services
    ├── account-service
    ├── auth-service
    ├── payment-service
    └── transfer-service
```

## 인프라 구성

| 모듈 | 역할 |
| --- | --- |
| `modules/vpc` | VPC, Public/Private/DB Subnet, IGW, NAT Gateway, Route Table 구성 |
| `modules/security` | ALB, App, DB Security Group 구성 |
| `modules/database` | RDS MySQL, DB Subnet Group, KMS, Secrets Manager 구성 |
| `modules/eks` | EKS Cluster, Managed Node Group, ECR, IRSA, EBS CSI Add-on 구성 |
| `modules/alb` | Application Load Balancer, Target Group, HTTP Listener 구성 |

## 서비스 구성

| 서비스 | 설명 | 주요 API |
| --- | --- | --- |
| `auth-service` | 회원가입, 로그인, MFA, JWT 발급, 사용자 관리 | `/api/v1/auth/*` |
| `account-service` | 계좌 조회, 잔액 조회, 거래내역 조회 | `/api/v1/accounts/*` |
| `payment-service` | 간편결제, 멱등성 처리, 일일 결제 한도, FDS | `/api/v1/payments/*` |
| `transfer-service` | 계좌이체, ACID 트랜잭션, 일일 송금 한도, FDS | `/api/v1/transfers/*` |

모든 서비스는 `/health` 엔드포인트를 제공합니다.

## 사전 요구사항

- AWS CLI
- Terraform `>= 1.6.0`
- kubectl
- Docker
- AWS 계정 및 배포 권한이 있는 IAM Role 또는 Profile

AWS CLI 프로필 예시:

```bash
aws configure --profile Lee-role
aws sts get-caller-identity --profile Lee-role
```

## Terraform 배포

1. 변수 확인

```bash
terraform.tfvars
```

주요 변수:

```hcl
region          = "ap-northeast-2"
env_name        = "prod"
node_group_name = "fin-prod-nodegroup"
```

2. 초기화

```bash
terraform init
```

3. 배포 계획 확인

```bash
terraform plan
```

4. 인프라 배포

```bash
terraform apply
```

배포가 끝나면 EKS kubeconfig가 자동으로 갱신됩니다.

```bash
kubectl get nodes
kubectl get pods -A
```

## 컨테이너 이미지 빌드 및 푸시

Terraform은 아래 서비스 이름으로 ECR Repository를 생성합니다.

- `account-service`
- `auth-service`
- `payment-service`
- `transfer-service`

ECR 로그인:

```bash
aws ecr get-login-password --region ap-northeast-2 --profile Lee-role \
  | docker login --username AWS --password-stdin <AWS_ACCOUNT_ID>.dkr.ecr.ap-northeast-2.amazonaws.com
```

서비스별 이미지 빌드 및 푸시 예시:

```bash
SERVICE_NAME=auth-service
AWS_ACCOUNT_ID=<AWS_ACCOUNT_ID>
REGION=ap-northeast-2

docker build -t ${SERVICE_NAME}:latest ./services/${SERVICE_NAME}
docker tag ${SERVICE_NAME}:latest ${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${SERVICE_NAME}:latest
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${SERVICE_NAME}:latest
```

다른 서비스도 `SERVICE_NAME` 값만 변경해 동일하게 진행합니다.

## Kubernetes 배포

서비스 매니페스트 적용:

```bash
kubectl apply -f services/auth-service/deployment.yaml
kubectl apply -f services/account-service/deployment.yaml
kubectl apply -f services/payment-service/deployment.yaml
kubectl apply -f services/transfer-service/deployment.yaml
```

배포 확인:

```bash
kubectl get deployments
kubectl get pods
kubectl get svc
```

> 현재 `deployment.yaml`의 이미지 주소와 컨테이너 포트는 Dockerfile/ECR Repository 이름과 다를 수 있습니다. 실제 배포 전에는 ECR 이미지 주소, `containerPort`, `targetPort`를 현재 빌드 이미지 기준으로 맞춰야 합니다.

## 환경 변수

서비스는 다음 환경 변수를 사용합니다.

| 변수 | 설명 |
| --- | --- |
| `DATABASE_URL` | PostgreSQL 접속 문자열 |
| `REDIS_URL` | Redis 접속 문자열 |
| `JWT_SECRET_KEY` | JWT 서명 키 |
| `ENCRYPTION_KEY` | AES-256-GCM 암호화 키. 64자리 hex 문자열 권장 |

Kubernetes 환경에서는 Secret 또는 External Secrets 방식으로 주입하는 것을 권장합니다.

## 보안 설계 포인트

- Public Subnet에는 ALB와 NAT Gateway만 배치
- EKS Node Group은 Private Subnet에 배치
- RDS는 DB Subnet에 배치하고 `publicly_accessible = false` 적용
- DB Security Group은 App Security Group에서 들어오는 3306 포트만 허용
- ECR 이미지는 KMS로 암호화하고 Push 시 취약점 스캔 수행
- EKS Secret 암호화를 위해 KMS 활성화
- AWS Load Balancer Controller와 EBS CSI Driver는 IRSA로 권한 분리
- 결제와 송금 API는 Redis 기반 중복 처리, 일일 한도, FDS 점수 계산 적용
- 계좌번호와 사용자명 등 민감 정보는 암호화 또는 마스킹 처리

## 운영 주의사항

- `terraform.tfvars`, `terraform.tfstate`, `.terraform/` 디렉터리는 민감 정보가 포함될 수 있으므로 Git에 커밋하지 않습니다.
- 운영 환경에서는 ALB HTTP 80 대신 HTTPS 443 리스너와 ACM 인증서를 적용하는 것을 권장합니다.
- 운영 환경에서는 ALB 앞단에 AWS WAF를 추가하는 것을 권장합니다.
- ECR 이미지 태그는 `latest`보다 Git SHA 또는 버전 태그를 사용하는 것이 안전합니다.
- 현재 비용 최적화를 위해 RDS Multi-AZ 기본값이 `false`입니다. 운영 고가용성이 필요하면 `is_prod_deployment = true`로 변경합니다.
- NAT Gateway는 비용 절감을 위해 1개만 생성됩니다. AZ 장애 대응이 필요하면 AZ별 NAT Gateway 구성을 검토합니다.

## 정리

테스트 후 리소스를 삭제하려면 다음 명령을 실행합니다.

```bash
terraform destroy
```

삭제 전 EKS LoadBalancer Service, ALB Controller가 생성한 리소스, ECR 이미지, RDS Snapshot 정책을 함께 확인하세요.
