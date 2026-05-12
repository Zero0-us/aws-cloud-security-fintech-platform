# Terraform - Corp Environment (본사 환경)

## 개요

금융 보안 핀테크 플랫폼의 **Corp(본사) 계정** AWS 인프라를 Terraform으로 구성한 코드입니다.

Corp 계정은 두 가지 핵심 허브 역할을 담당합니다.

- **VPN Hub**: Corp 온프레미스 네트워크(192.168.0.0/16)와 각 AWS 계정(Prod/Dev/SOC/Stg) 간 Site-to-Site VPN 연결 거점
- **IAM Hub**: 모든 IAM 사용자를 Corp 계정에 생성하고, 타 계정의 역할(Role)을 AssumeRole로 수임하는 중앙 자격증명 관리

## 아키텍처

```
Corp 온프레미스 (192.168.0.0/16)
           │
           │ StrongSwan IPsec VPN
           ▼
┌─── Corp VPC (192.168.0.0/16) ───┐
│  fin-corp-vpn-ec2 (EIP)         │
│  Public Subnet 2a/2c            │
└──────────────┬──────────────────┘
               │ IPsec Tunnels (Libreswan 상대방)
       ┌───────┼───────┬──────────┐
       ▼       ▼       ▼          ▼
   Dev VPC  Prod VPC  SOC VPC  Stg VPC
 (10.30.x) (10.20.x) (10.10.x) (10.40.x)
```

```
Corp 계정 IAM 사용자
    │ sts:AssumeRole (MFA 필수)
    ├──→ Prod: System-Admin-Role / Prod-Viewer-Role
    ├──→ Dev:  System-Admin-Role / Dev-Manager-Role
    └──→ SOC:  System-Admin-Role / Security-Audit-Role
```

## 파일 구조

| 파일 | 설명 |
|------|------|
| `providers.tf` | AWS 프로바이더 설정 (profile: `fintech-corp`, 리전: `ap-northeast-2`) |
| `main.tf` | VPC 모듈 + VPN 모듈 호출 |
| `variables.tf` | 변수 정의 (VPN 대상 계정 정보, IAM 사용자 목록, 계정 ID 등) |
| `iam.tf` | Corp IAM User 생성, MFA 강제 정책, AssumeRole 정책 |
| `outputs.tf` | VPN EIP, VPC ID 등 출력 |
| `modules/vpc/` | VPC, Public Subnet 2개(2AZ), IGW, 라우팅 테이블 |
| `modules/vpn/` | VPN EC2 (StrongSwan), EIP 연결, 보안그룹, 라우팅, SSM Role |

## 네트워크 설계

| 구분 | CIDR | 용도 |
|------|------|------|
| Corp VPC | 192.168.0.0/16 | 본사 온프레미스 대역 |
| Public Subnet 2a | 192.168.1.0/24 | VPN EC2 배치 |
| Public Subnet 2c | 192.168.2.0/24 | 예비 |

## VPN 구성 (StrongSwan)

Corp 계정에서는 **StrongSwan**을 사용하고, 상대방 계정(Prod/Dev/SOC)에서는 **Libreswan**을 사용합니다.

| 항목 | 값 |
|------|-----|
| VPN EC2 | `fin-corp-vpn-ec2` |
| EIP | `terraform output vpn_eip` |
| VPN 소프트웨어 | StrongSwan |
| PSK | `variables.tf`의 `target_accounts` 맵 참고 (노션) |

### 연결 대상 계정

| 계정 | VPC CIDR | EIP 변수 |
|------|----------|----------|
| Dev | 10.30.0.0/16 | `target_accounts.dev.eip` |
| Prod | 10.20.0.0/16 | `target_accounts.prod.eip` |
| SOC | 10.10.0.0/16 | `target_accounts.soc.eip` |
| Stg | 10.40.0.0/16 | `target_accounts.staging.eip` |

### VPN 설정 절차

1. `terraform apply` 후 `vpn_eip` 출력값을 각 계정 담당자에게 전달
2. 각 계정에서 VPN EC2 EIP를 `target_accounts.<계정>.eip`에 입력 후 재 apply
3. Corp SSM 접속 후 StrongSwan 설정

```bash
# SSM 접속
aws ssm start-session --target <인스턴스ID> --profile fintech-corp

# VPN 상태 확인
sudo strongswan status
```

## IAM 구성

Corp 계정에 IAM 사용자를 생성하고, 각 계정의 Role을 AssumeRole로 수임합니다.

### IAM 사용자 추가 방법

`variables.tf`의 `iam_users` 맵에 사용자와 역할을 추가한 후 apply합니다.

```hcl
iam_users = {
  "hong.gildong" = { roles = ["system_admin"] }        # Prod Admin
  "kim.cheolsu"  = { roles = ["prod_viewer"] }         # Prod 읽기 전용
  "lee.younghee" = { roles = ["dev_manager"] }         # Dev 관리자
  "park.audit"   = { roles = ["security_audit"] }      # SOC 보안 감사
}
```

### 지원 역할(Role) 목록

| 역할 키 | AssumeRole 대상 | 정책 |
|---------|----------------|------|
| `system_admin` | Prod의 System-Admin-Role | AdministratorAccess |
| `prod_viewer` | Prod의 Prod-Viewer-Role | ViewOnlyAccess |
| `dev_manager` | Dev의 Dev-Manager-Role | PowerUserAccess |
| `security_audit` | SOC의 Security-Audit-Role | SecurityAudit + ReadOnly |
| `dev_system_admin` | Dev의 System-Admin-Role | AdministratorAccess |
| `soc_system_admin` | SOC의 System-Admin-Role | AdministratorAccess |
| `stg_system_admin` | Stg의 System-Admin-Role | AdministratorAccess |

### MFA 강제

모든 Corp IAM 사용자에게 `fin-corp-force-mfa` 정책이 부착됩니다.
MFA 미설정 시 AssumeRole을 포함한 대부분의 작업이 차단됩니다.

### Apply 순서

> Corp IAM이 타 계정의 Role ARN을 참조하므로, 타 계정 먼저 apply해야 합니다.

1. **Prod / Dev / SOC / Stg** 계정 `iam.tf` apply → 각 계정에 Role 생성
2. **Corp** 계정 `iam.tf` apply → IAM User + MFA 정책 + AssumeRole 정책 생성

```bash
# 계정 ID 확인 후 variables.tf에 입력
# prod_account_id, dev_account_id, soc_account_id, stg_account_id

terraform -chdir=terraform/corp init
terraform -chdir=terraform/corp plan
terraform -chdir=terraform/corp apply
```

## 사전 준비

1. **AWS CLI 프로필 설정**
   ```bash
   aws configure --profile fintech-corp
   ```

2. **EIP 사전 생성** (콘솔에서 수동)
   - Corp VPN EC2에 붙일 EIP를 콘솔에서 생성 후 Allocation ID를 `corp_eip_allocation_id`에 입력

3. **타 계정 ID 입력**
   - `variables.tf`의 `prod_account_id`, `dev_account_id`, `soc_account_id`, `stg_account_id`에 각 계정 AWS 계정 ID 입력

## ⚠️ 주의사항

- `target_accounts`의 PSK는 `terraform.tfvars`로 관리하고 Git에 올리지 마세요.
- Corp IAM apply는 반드시 타 계정 Role 생성 이후에 진행합니다.
- `terraform.tfstate`는 `.gitignore`로 제외합니다. 팀 작업 시 S3 Backend 설정을 권장합니다.
- IAM 사용자 삭제 시 `iam_users`에서 제거 후 `terraform apply`를 실행합니다.

## 계정 구조

| 계정 | VPC CIDR | 용도 |
|------|----------|------|
| **Corp (이 코드)** | **192.168.0.0/16** | **VPN Hub + IAM Hub** |
| SOC/Audit | 10.10.0.0/16 | 보안 로그 수집, 관제 |
| Prod | 10.20.0.0/16 | 실제 운영 환경 |
| Dev | 10.30.0.0/16 | 개발/테스트 환경 |
| Stg | 10.40.0.0/16 | 스테이징 환경 (구현 예정) |
