# Terraform - Dev Environment (개발 환경)

## 개요

금융 보안 핀테크 플랫폼의 **Dev 계정** AWS 인프라를 Terraform으로 구성한 코드입니다.

> 전자금융감독규정 제5조에 따라 네트워크를 3계층(Public/Private/DB)으로 분리하였습니다.

## 아키텍처

```
Internet
   │
   ▼
┌──────────────── fin-dev-vpc (10.30.0.0/16) ────────────────┐
│                                                             │
│  ┌─ Public Subnet (10.30.1-2.0/24) ─┐                     │
│  │  ALB (fin-dev-alb)                │                     │
│  │  NAT Gateway                      │                     │
│  └───────────────┬───────────────────┘                     │
│                  │                                          │
│  ┌─ Private Subnet (10.30.10-11.0/24) ┐                   │
│  │  EKS Nodes (fin-dev-eks)            │                   │
│  └───────────────┬─────────────────────┘                   │
│                  │                                          │
│  ┌─ DB Subnet (10.30.20-21.0/24) ─────┐                   │
│  │  RDS MySQL (fin-dev-db)             │                   │
│  └─────────────────────────────────────┘                   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
         │ VPC Peering
         ▼
  Security/Audit VPC (10.10.0.0/16)
         │
         │ IPsec VPN
         ▼
  Corp VPC (192.168.0.0/16)
```

## 파일 구조

| 파일 | 설명 |
|------|------|
| `provider.tf` | AWS 프로바이더 설정 (profile: `dev`, 리전: `ap-northeast-2`) |
| `vpc.tf` | VPC, 서브넷 6개(3계층×2AZ), IGW, NAT Gateway, 라우팅 테이블 |
| `security_groups.tf` | 보안 그룹 3개 (ALB → EKS → RDS 체인) |
| `eks.tf` | EKS 클러스터 (v1.29), Spot 노드그룹 (t3.small, 1~2대) |
| `rds.tf` | RDS MySQL 8.0 (db.t3.micro, Single-AZ, 20GB GP3) |
| `alb.tf` | ALB, 타겟 그룹, HTTP 리스너 |
| `vpc_peering.tf` | Dev → Security/Audit VPC 피어링 + 라우팅 |
| `outputs.tf` | VPC ID, EKS 엔드포인트, RDS 주소 등 출력 |
| `vpn-instance.tf` | Corp VPN 연결용 EC2 (Libreswan), EIP, 보안그룹, IAM Role |
| `iam.tf` | 비즈니스 IAM Role (System-Admin-Role, Dev-Manager-Role) |

## 네트워크 설계

| 구분 | 서브넷 | CIDR | AZ | 용도 |
|------|--------|------|----|------|
| Public | fin-dev-pub-sub-2a | 10.30.1.0/24 | 2a | ALB, NAT GW |
| Public | fin-dev-pub-sub-2c | 10.30.2.0/24 | 2c | ALB |
| Private | fin-dev-pri-sub-2a | 10.30.10.0/24 | 2a | EKS Nodes |
| Private | fin-dev-pri-sub-2c | 10.30.11.0/24 | 2c | EKS Nodes |
| DB | fin-dev-db-sub-2a | 10.30.20.0/24 | 2a | RDS Primary |
| DB | fin-dev-db-sub-2c | 10.30.21.0/24 | 2c | RDS (서브넷 그룹용) |

## 보안 그룹 체인

```
인터넷 → [ALB-SG: 80/443] → [EKS-SG: ALB에서만] → [RDS-SG: 3306, EKS에서만]
```

- **fin-dev-alb-sg**: HTTP(80), HTTPS(443) from `0.0.0.0/0`
- **fin-dev-eks-node-sg**: ALL TCP from ALB-SG + Self + VPC 내부
- **fin-dev-rds-sg**: MySQL(3306) from EKS-SG only

## 사전 준비

1. **Terraform 설치** (>= 1.0)
   ```bash
   # Windows (winget)
   winget install HashiCorp.Terraform
   ```

2. **AWS CLI 프로필 설정**
   ```bash
   aws configure --profile dev
   # Access Key, Secret Key, Region(ap-northeast-2) 입력
   ```

3. **VPC 피어링 수락**
   - `vpc_peering.tf`에서 피어링 요청 생성 후, **Security/Audit 계정**(399707826519)에서 수락 필요

4. **Corp 계정 ID 입력** (IAM Role 사용 시)
   - `iam.tf`의 `corp_account_id` 변수에 Corp AWS 계정 ID 입력
   - Corp 계정 apply 후 `iam.tf`의 AssumeRole 정책에서 이 Dev 계정 IAM Role을 허용해야 함

## 사용법

```bash
# 1. 이 디렉토리로 이동
cd terraform/dev

# 2. Terraform 초기화 (프로바이더 다운로드)
terraform init

# 3. 실행 계획 확인 (실제 생성 전 미리보기)
terraform plan

# 4. 인프라 생성
terraform apply

# 5. 생성된 리소스 정보 확인
terraform output
```

## 주요 리소스 비용 (참고)

| 리소스 | 예상 비용 | 비고 |
|--------|-----------|------|
| EKS 컨트롤 플레인 | ~$73/월 | 고정 과금 |
| NAT Gateway | ~$32/월 | + 데이터 전송 비용 |
| ALB | ~$16/월 | + 요청 수 기반 |
| RDS db.t3.micro | 프리티어 | 12개월 750시간/월 무료 |
| EKS Spot Node (t3.small) | ~$5~8/월 | 스팟 할인 적용 |

## ⚠️ 주의사항

- `rds.tf`의 DB 비밀번호는 학습용입니다. **실제 운영 시 AWS Secrets Manager를 사용하세요.**
- `terraform.tfstate` 파일은 `.gitignore`로 제외되어 있습니다. 팀 작업 시 **S3 Backend** 설정을 권장합니다.
- `terraform destroy` 시 모든 리소스가 삭제됩니다. 주의하세요.
- VPC 피어링 생성 후 반드시 **상대 계정에서 수락**해야 통신이 됩니다.

## 계정 구조

| 계정 | VPC CIDR | 용도 |
|------|----------|------|
| Security/Audit | 10.10.0.0/16 | 보안 로그 수집, Bastion |
| **Dev (이 코드)** | **10.30.0.0/16** | **개발/테스트 환경** |
| Prod | 10.20.0.0/16 | 실제 운영 환경 |


## Corp VPN 연결

Corp(본사)와 Site-to-Site VPN 연결을 위한 EC2 기반 구성입니다.

| 항목 | 값 |
|------|-----|
| VPN EC2 | `fin-dev-vpn-ec2` |
| EIP | `terraform output vpn_fixed_ip` |
| Corp CIDR | `192.168.0.0/16` |
| PSK | 노션 참고 |

### 설정 방법

1. `terraform apply` 후 `vpn_fixed_ip` 출력값을 Corp에 전달
2. Corp에서 VPN IP, PSK 전달받음
3. SSM 접속 후 Libreswan 설정

```bash
# SSM 접속
aws ssm start-session --target <인스턴스ID>

# VPN 상태 확인
sudo ipsec status
```

성공 시:
```
"corp-vpn": STATE_V2_ESTABLISHED_IKE_SA
"corp-vpn": STATE_V2_ESTABLISHED_CHILD_SA
```

## IAM Role

Corp 계정을 IAM Hub로 사용하는 Cross-account 역할 위임 구성입니다.

| Role 이름 | 정책 | 신뢰 주체 |
|-----------|------|-----------|
| `System-Admin-Role` | AdministratorAccess | Corp 계정 root (MFA 필수) |
| `Dev-Manager-Role` | PowerUserAccess | Corp 계정 root (MFA 필수) |

Corp 계정의 IAM 사용자가 `sts:AssumeRole`로 이 Dev 계정의 Role을 수임합니다.

### Apply 순서

1. Dev 계정 `iam.tf` apply → Role 생성
2. Corp 계정 `iam.tf` apply → IAM User + AssumeRole 정책 생성