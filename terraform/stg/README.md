# STG 환경 - AWS Cloud Security Fintech Platform

JOA OpenAPI 기반 핀테크 서비스를 AWS EKS 위에 배포하기 위한 Staging 인프라 코드입니다.

> 원본: [rheeeuro/joa-openapi](https://github.com/rheeeuro/joa-openapi) (SSAFY 10기 프로젝트) - 원작자 사용 허락 완료

## 아키텍처

```text
Internet
  |
  v
Route 53 (stg.fin-api.com / api.stg.fin-api.com)
  |
  v
WAF (AWS Managed Rules)
  |
  v
ALB (fin-stg-alb, HTTP :80)
  |
  |-- /              -> bank-web        :3000
  |-- /admin         -> admin-frontend  :3000
  |-- /docs          -> docs-frontend   :3000
  |-- /v1            -> openapi-backend :8080
  |-- /member        -> bank-backend    :8080
  |-- /admin/api     -> admin-backend   :8080
  `-- /actuator/health -> openapi-backend :8080
  |
  v
EKS Cluster (fin-stg-eks, Kubernetes 1.29)
  |-- Private Subnet 2a (10.40.10.0/24)
  `-- Private Subnet 2c (10.40.11.0/24)
  |
  v
RDS MySQL 8.0 (fin-stg-db)
  |-- DB Subnet 2a (10.40.20.0/24)
  `-- DB Subnet 2c (10.40.21.0/24)
```

## 서비스 구성

| 서비스 | 기술 스택 | 포트 | 설명 |
| --- | --- | --- | --- |
| `bank-backend` | Spring Boot 3.2 + JPA | 8080 | 회원 가입, 로그인, 로그아웃, 이메일 인증 |
| `openapi-backend` | Spring Boot 3.2 + JPA | 8080 | 계좌 CRUD, 거래내역, 송금, 금융상품, 은행 관리 |
| `admin-backend` | Spring Boot 3.2 + QueryDSL | 8080 | 관리자 대시보드 API, JWT 인증 |
| `admin-frontend` | Next.js 15 + Tailwind + Flowbite | 3000 | 관리자 대시보드 웹 UI |
| `bank-web` | Next.js 14 + Tailwind | 3000 | 모바일 뱅킹 웹 |
| `docs-frontend` | Swagger UI | 3000 | OpenAPI 문서 |
| `redis` | Redis 7 Alpine | 6379 | 세션/캐시 |

## 디렉터리 구조

```text
.
|-- main.tf                 # 루트 모듈: VPC, Security, DB, EKS, ALB, WAF, Route53 호출
|-- monitoring.tf           # STG -> Audit Account(SOC) 로그 전송
|-- providers.tf            # AWS, Kubernetes, Helm provider
|-- variables.tf            # 환경 변수 기본값(stg)
|-- outputs.tf              # VPN 관련 출력값
|-- vpc_peering.tf          # STG VPC -> Audit Account(SOC) VPC peering 요청
|-- vpn-instance.tf         # Corp VPN 연결용 EC2/EIP/보안그룹/IAM Role
|-- iam.tf                  # Cross-account IAM Role
|-- modules/
|   |-- vpc/                # VPC, Subnet, IGW, NAT GW, Route Table
|   |-- security/           # ALB/App/DB Security Group
|   |-- database/           # RDS MySQL, KMS, Secrets Manager
|   |-- eks/                # EKS, Node Group, ECR, IRSA, EBS CSI
|   |-- alb/                # ALB, Target Group, Listener
|   |-- waf/                # WAFv2 Web ACL + ALB association
|   `-- route53/            # Hosted Zone + ALB Alias Record
`-- services/
    |-- configmap.yaml
    |-- secrets.yaml
    |-- ingress.yaml
    |-- redis.yaml
    |-- db-init.sql
    |-- bank-backend/
    |-- openapi-backend/
    |-- admin-backend/
    |-- admin-frontend/
    |-- bank-web/
    `-- docs-frontend/
```

## Terraform 구성

| 모듈 | 주요 리소스 | 기본값/보안 |
| --- | --- | --- |
| `vpc` | VPC, Public/Private/DB Subnet x 2 AZ, IGW, NAT GW | `10.40.0.0/16`, 3계층 네트워크 분리 |
| `security` | ALB/App/DB Security Group | ALB 80, App 3000/8080, DB 3306 최소 허용 |
| `database` | RDS MySQL 8.0, Secrets Manager, KMS | `db.t3.micro`, `is_prod_deployment=false`라 Multi-AZ 비활성 |
| `eks` | EKS 1.29, Managed Node Group, ECR 6개, IRSA | Secret KMS 암호화, Control Plane Logging 활성화 |
| `alb` | Internet-facing ALB, Target Group, HTTP Listener | Pod 직접 연결용 `target_type=ip` |
| `waf` | AWS Managed Rules | Common, SQLi, KnownBadInputs 룰셋 |
| `route53` | Hosted Zone, A Alias | `stg.fin-api.com`, `api.stg.fin-api.com` |
| `monitoring.tf` | VPC Flow Logs, CloudTrail, AWS Config | Audit Account(SOC)의 `fin-stg-log-s3`로 로그 전송 |

기본 환경명은 `stg`입니다. 운영 환경으로 배포할 때는 `env_name`, CIDR, 노드 크기, `is_prod_deployment` 등을 별도 `tfvars`로 분리해 적용하세요.

## 사전 요구사항

- AWS CLI
- Terraform >= 1.6.0
- kubectl
- Helm
- Docker

AWS 프로필을 명시하려면 `terraform.tfvars` 또는 CLI 변수로 `aws_profile`을 설정합니다.

```hcl
aws_profile = "Lee-role"
```

## 배포 절차

### 1. 인프라 배포

```bash
terraform init
terraform plan
terraform apply
```

EKS 모듈의 `null_resource.update_kubeconfig`가 배포 후 kubeconfig를 갱신합니다. 적용 후 노드를 확인합니다.

```bash
kubectl get nodes
```

### 2. ConfigMap / Secret 업데이트

`services/configmap.yaml`의 `DB_HOST`는 실제 RDS 엔드포인트로 교체해야 합니다.

```bash
aws rds describe-db-instances \
  --db-instance-identifier fin-stg-db \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text
```

RDS 비밀번호는 Terraform이 Secrets Manager의 `fin-stg-db-password-v2`에 생성합니다. `services/secrets.yaml`에 넣을 값은 base64로 인코딩합니다.

```bash
echo -n '실제값' | base64
```

`services/secrets.yaml`은 예시 파일입니다. 실제 운영 비밀번호나 JWT 키를 저장소에 커밋하지 마세요.

### 3. Docker 이미지 빌드 및 ECR Push

ECR 계정 ID는 현재 배포 계정에 맞게 바꿔 사용합니다. 이 저장소의 Kubernetes 매니페스트는 현재 `423401347162.dkr.ecr.ap-northeast-2.amazonaws.com/<service>:latest` 형식을 참조합니다.

```bash
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=ap-northeast-2

aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
```

예시:

```bash
docker build -t bank-web:latest services/bank-web/app
docker tag bank-web:latest "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/bank-web:latest"
docker push "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/bank-web:latest"
```

Spring Boot 백엔드와 관리자 프론트엔드는 JOA 원본 소스 경로를 빌드 컨텍스트로 사용합니다.

```bash
docker build -t bank-backend:latest -f services/bank-backend/Dockerfile /path/to/joa-openapi/bank/backend
docker build -t openapi-backend:latest -f services/openapi-backend/Dockerfile /path/to/joa-openapi/openapi/backend
docker build -t admin-backend:latest -f services/admin-backend/Dockerfile /path/to/joa-openapi/admin/backend
docker build -t admin-frontend:latest -f services/admin-frontend/Dockerfile /path/to/joa-openapi/admin/frontend
docker build -t docs-frontend:latest services/docs-frontend
```

### 4. Kubernetes 매니페스트 배포

```bash
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
```

확인:

```bash
kubectl get pods
kubectl get ingress
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

## DB 스키마

`services/db-init.sql`에 JOA 서비스용 초기 스키마가 포함되어 있습니다.

| 테이블 | 설명 |
| --- | --- |
| `member` | 회원 정보 |
| `account` | 계좌 |
| `transaction` | 거래 내역 |
| `product` | 금융 상품 |
| `bank` | 은행 정보 |
| `dummy` | 더미 계좌 |
| `admin` | 관리자 |
| `api_key` | API 키 관리 |

## 보안 설계

- Public(ALB/NAT) -> Private(EKS) -> DB(RDS) 3계층 네트워크 분리
- EKS Secret과 RDS Storage에 KMS CMK 적용
- EKS Control Plane Logging 전체 활성화
- ECR Push 시 취약점 스캔 및 KMS 암호화 적용
- ALB Controller와 EBS CSI Driver에 IRSA 적용
- RDS 비밀번호는 Secrets Manager에서 생성 및 보관
- WAFv2 Managed Rule로 Common/SQLi/KnownBadInputs 방어
- SOC VPC ID가 입력된 경우에만 VPC Peering 생성
- VPC Flow Logs, CloudTrail, AWS Config 로그를 Audit Account(SOC) S3로 전송

## Audit Account (SOC) 연동

draw.io의 `SOC (Audit) VPC 상세` 기준으로 STG 계정은 다음 항목을 Audit Account(SOC)와 연동합니다.

- STG VPC `fin-stg-vpc (10.40.0.0/16)` -> SOC VPC `10.10.0.0/16` VPC Peering
- VPC Flow Logs -> CloudWatch Logs + SOC S3
- CloudTrail -> CloudWatch Logs + SOC S3
- AWS Config -> SOC S3

`soc_vpc_id`가 비어 있으면 Peering 리소스는 생성되지 않습니다. 값을 입력하면 STG VPC에서 SOC VPC로 피어링 요청을 생성하고, SOC 계정에서 별도로 수락해야 합니다.

SOC 연결 정보는 Terraform 변수 파일에 커밋하지 말고 환경변수로 주입합니다.

```bash
export TF_VAR_soc_vpc_id="vpc-xxxxxxxxxxxxxxxxx"
export TF_VAR_soc_account_id="<soc-account-id>"
export TF_VAR_soc_vpc_cidr="10.10.0.0/16"
export TF_VAR_soc_log_bucket_name="fin-stg-log-s3"
export TF_VAR_soc_log_bucket_prefix="stg"

terraform plan
terraform apply
```

기존 `audit_vpc_id`, `audit_account_id` 변수도 호환용으로 남겨두었지만, 신규 설정은 `soc_*` 변수를 사용하세요.

| 항목 | 값 |
| --- | --- |
| Source | STG VPC (`10.40.0.0/16`) |
| Destination | Audit Account(SOC) VPC (`10.10.0.0/16`) |
| SOC Account | `TF_VAR_soc_account_id` |
| SOC Log Bucket | `TF_VAR_soc_log_bucket_name` (예: `fin-stg-log-s3`) |

STG 쪽 Terraform은 Public, Private, DB 라우트 테이블에 `soc_vpc_cidr` 경로를 추가합니다. SOC 계정에서는 다음 작업이 별도로 필요합니다.

1. VPC Peering 요청 수락
2. SOC VPC 라우트 테이블에 STG CIDR(`10.40.0.0/16`) -> Peering Connection 경로 추가
3. `fin-stg-log-s3` 버킷 정책에서 STG 계정의 VPC Flow Logs, CloudTrail, AWS Config 쓰기 허용
4. SOC 수집기 또는 분석 서버 Security Group에서 필요한 STG CIDR/포트 허용

SOC 계정의 GuardDuty, Security Hub, Athena, Glue, Lambda Monthly Audit Report, KMS, S3 버킷은 SOC 계정 Terraform에서 관리합니다. 이 STG 저장소는 로그 송신 리소스만 생성합니다.

## Corp VPN

Corp와 Site-to-Site VPN 연결을 위한 EC2 기반 구성입니다.

| 항목 | 값 |
| --- | --- |
| VPN EC2 | `fin-stg-vpn-ec2` |
| EIP | `terraform output vpn_fixed_ip` |
| Corp CIDR | `192.168.0.0/16` |
| PSK | 별도 보안 문서 참고 |

SSM 접속 후 Libreswan 상태를 확인합니다.

```bash
sudo ipsec status
```

## IAM Role

Corp 계정을 IAM Hub로 사용하는 Cross-account 역할 위임 구성입니다. `corp_account_id`를 입력해야 신뢰 정책이 올바르게 구성됩니다.

| Role 이름 | 정책 | 신뢰 주체 |
| --- | --- | --- |
| `System-Admin-Role` | `AdministratorAccess` | Corp 계정 root, MFA 조건 |
| `Prod-Viewer-Role` | `ViewOnlyAccess` | Corp 계정 root, MFA 조건 |

## 운영 참고

- 운영 배포에서는 `env_name=prod`, 별도 CIDR, Multi-AZ RDS, 더 큰 노드 타입을 사용하는 `tfvars`를 분리하세요.
- ALB는 현재 HTTP 80 리스너만 구성되어 있습니다. 외부 서비스 전에는 ACM 인증서와 HTTPS 443 리스너를 추가하세요.
- ECR 이미지 태그는 `latest`보다 커밋 해시나 릴리스 버전을 권장합니다.
- NAT Gateway는 비용 절감을 위해 1개만 생성합니다. AZ 장애 대응이 필요하면 AZ별 NAT로 확장하세요.
- `services/secrets.yaml`의 값은 예시입니다. 실제 민감정보는 External Secrets Operator 등으로 분리하는 구성을 권장합니다.

## 정리

Kubernetes 리소스를 먼저 제거한 뒤 Terraform 인프라를 삭제합니다.

```bash
kubectl delete -f services/ingress.yaml
kubectl delete -f services/docs-frontend/deployment.yaml
kubectl delete -f services/bank-web/deployment.yaml
kubectl delete -f services/admin-frontend/deployment.yaml
kubectl delete -f services/admin-backend/deployment.yaml
kubectl delete -f services/openapi-backend/deployment.yaml
kubectl delete -f services/bank-backend/deployment.yaml
kubectl delete -f services/redis.yaml
kubectl delete -f services/secrets.yaml
kubectl delete -f services/configmap.yaml

terraform destroy
```
