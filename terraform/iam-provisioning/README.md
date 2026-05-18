# 🛡️ IAM Provisioning Automation System

> AWS 멀티 계정 환경에서 IAM 사용자 생명주기를 자동화하는 보안 시스템

YAML 한 장으로 입사자 IAM 생성, 퇴사자 권한 회수, 권한 변경을 모두 자동화합니다.
4-Eye Principle 기반 승인 워크플로우와 완전한 감사 추적을 제공합니다.

[![AWS](https://img.shields.io/badge/AWS-Multi--Account-orange)]()
[![Terraform](https://img.shields.io/badge/Terraform-1.5+-purple)]()
[![Python](https://img.shields.io/badge/Python-3.11-blue)]()

---

## 📑 목차

- [핵심 기능](#-핵심-기능)
- [아키텍처](#-아키텍처)
- [기술 스택](#-기술-스택)
- [사전 요구사항](#-사전-요구사항)
- [배포 가이드](#-배포-가이드)
- [사용 방법](#-사용-방법)
- [요청 시나리오](#-요청-시나리오)
- [보안 기능](#-보안-기능)
- [모니터링](#-모니터링)
- [디렉토리 구조](#-디렉토리-구조)
- [트러블슈팅](#-트러블슈팅)

---

## ✨ 핵심 기능

### 🟢 입사 처리 (Onboard)
- IAM User 자동 생성
- 임시 비밀번호 발급 (강제 변경 설정)
- Role 기반 정책 자동 부착
- 다중 계정 동시 처리

### 🔴 퇴사 처리 (Offboard)
- 콘솔 로그인 즉시 차단
- Access Key 자동 비활성화
- 모든 정책 일괄 제거
- 감사 로그 영구 보존

### 🟡 권한 변경 (Modify)
- 기존 정책 제거 + 신규 정책 부착
- 변경 이력 자동 기록
- 다중 역할 동시 변경

### 🛡️ 보안 검증
- **4-Eye Principle**: 요청자 ≠ 승인자
- **역할 화이트리스트**: 허용된 역할만 부여 가능
- **Race Condition 방지**: DynamoDB ConditionExpression
- **봇 자동 클릭 차단**: User-Agent 검증
- **중복 요청 차단**: 동일 request_id 거부
- **확인 페이지**: GET → HTML → POST 2단계 처리

---

## 🏗️ 아키텍처

```
┌─────────────┐
│  사용자 (HR) │  YAML 파일 작성
└──────┬──────┘
       │ ① S3 업로드
       ↓
┌─────────────────────┐
│  S3 Bucket          │
│  /requests/onboard/ │
│  /requests/offboard/│
│  /requests/modify/  │
└──────┬──────────────┘
       │ ② 이벤트 발생
       ↓
┌─────────────────────┐
│  EventBridge        │
└──────┬──────────────┘
       │ ③ Lambda 트리거
       ↓
┌─────────────────────┐
│  request_parser     │  YAML 파싱 + 검증 + 중복 체크
└──────┬──────────────┘
       │ ④ DB 저장 + 알림
       ├──────────────┬
       ↓              ↓
┌────────────┐  ┌──────────────┐
│  DynamoDB  │  │  Discord     │
│  pending   │  │  Webhook     │ ──→ 보안팀 알림
└────────────┘  └──────┬───────┘     [✅승인] [❌거부]
                       │ ⑤ 사용자 클릭
                       ↓
                ┌──────────────────┐
                │  API Gateway     │
                │  /approve /deny  │
                └──────┬───────────┘
                       │ ⑥ Lambda 호출
                       ↓
                ┌──────────────────┐
                │  approval_       │  봇 차단 + 확인 페이지
                │  handler         │  Race Condition 방지
                └──────┬───────────┘
                       │ ⑦ 워크플로우 시작
                       ↓
                ┌──────────────────┐
                │  Step Functions  │  요청 타입별 분기
                └──────┬───────────┘
                       │ ⑧ IAM 작업 실행
                       ↓
                ┌──────────────────┐
                │  iam_executor    │  STS AssumeRole
                └──────┬───────────┘  Cross-Account
                       │ ⑨ 다른 계정 IAM 작업
                       ↓
                ┌──────────────────┐
                │  Target Account  │  실제 IAM 생성/변경
                └──────┬───────────┘
                       │ ⑩ 완료 알림
                       ↓
                ┌──────────────────┐
                │ discord_notifier │ ──→ Discord
                └──────────────────┘     "✅ 완료"
                       
                ┌──────────────────┐
                │  DynamoDB        │ ← 모든 작업 감사 기록
                │  audit_logs      │
                └──────────────────┘
```

---

## 🛠️ 기술 스택

| 카테고리 | 서비스 | 용도 |
|---------|--------|------|
| **컴퓨팅** | AWS Lambda (Python 3.11) | 비즈니스 로직 |
| **워크플로우** | AWS Step Functions | 작업 오케스트레이션 |
| **스토리지** | Amazon S3 | YAML 요청 저장 |
| **데이터베이스** | Amazon DynamoDB | 요청 상태 + 감사 로그 |
| **API** | Amazon API Gateway (HTTP API) | 승인/거부 엔드포인트 |
| **이벤트** | Amazon EventBridge | S3 이벤트 라우팅 |
| **모니터링** | CloudWatch Logs/Metrics | 로그 + 메트릭 |
| **알림** | Discord Webhook | 실시간 알림 |
| **IaC** | Terraform | 인프라 코드 |

---

## 📋 사전 요구사항

### 필수 도구
- Terraform >= 1.5
- AWS CLI v2
- Python 3.11+ (로컬 테스트용)

### AWS 권한
- IAM 관리 권한
- Lambda, S3, DynamoDB, Step Functions, API Gateway 생성 권한
- EventBridge 권한

### 외부 서비스
- Discord 서버 + Webhook URL

---

## 🚀 배포 가이드

### 1. 저장소 클론

```bash
git clone <repository-url>
cd terraform/iam-provisioning
```

### 2. AWS 자격증명 설정

```bash
aws configure
# 또는
export AWS_PROFILE=your-profile
```

### 3. 변수 파일 생성

```bash
cp terraform.tfvars.example terraform.tfvars
```

`terraform.tfvars`를 본인 환경에 맞게 수정:

```hcl
# Discord Webhook URL
discord_webhook_url = "https://discord.com/api/webhooks/..."

# 대상 계정 ID (실제 12자리 AWS 계정 ID)
target_account_ids = {
  dev  = "123456789012"
  stg  = "234567890123"
  prod = "345678901234"
  soc  = "456789012345"
  corp = "567890123456"
}

# 단일 계정 테스트 시
deploy_cross_account_role = true
corp_account_id = "123456789012"
```

### 4. Terraform 초기화 및 배포

```bash
terraform init
terraform plan
terraform apply
```

### 5. 배포 확인

```bash
# Output 확인
terraform output

# 주요 리소스 확인
aws s3 ls s3://fin-iam-provisioning-requests-<account_id>/
aws lambda list-functions --query "Functions[?contains(FunctionName, 'fin-iam')]"
```

### 6. 멀티 계정 운영 시 추가 설정

각 대상 계정(dev, stg, prod 등)에 `IAMProvisioningExecutorRole` 별도 배포 필요:

```bash
# 대상 계정 자격증명으로 변경
export AWS_PROFILE=target-account-profile

# 변수 파일 수정
# - deploy_cross_account_role = true
# - corp_account_id = "<Corp 계정 ID>"

# 배포
terraform apply
```

---

## 📝 사용 방법

### 입사 요청 (Onboard)

#### 1. YAML 파일 작성

```yaml
# onboard-request.yaml
request_type: onboard
request_id: ONB-20260516-001

user:
  username: hong-gd
  email: hong@company.com
  department: 개발팀

access:
  target_accounts:
    - dev
    - stg
  roles:
    - ReadOnly
    - Dev-Manager

request:
  requester: hr-team
  requested_at: "2026-05-16T10:00:00+09:00"
```

#### 2. S3 업로드

```bash
aws s3 cp onboard-request.yaml \
  s3://fin-iam-provisioning-requests-<account_id>/requests/onboard/
```

#### 3. Discord에서 승인

Discord 채널에 알림이 오면:
1. ✅ 승인하기 또는 ❌ 거부하기 클릭
2. 확인 페이지에서 한 번 더 클릭
3. 자동으로 IAM 사용자 생성

---

### 퇴사 요청 (Offboard)

```yaml
# offboard-request.yaml
request_type: offboard
request_id: OFF-20260516-001

user:
  username: park-yh

deactivation:
  target_accounts:
    - dev
    - stg
    - prod
  actions:
    - disable_console_access
    - deactivate_access_keys
    - detach_all_policies

request:
  requester: hr-team
  requested_at: "2026-05-16T18:00:00+09:00"
  reason: "퇴사 처리"
```

```bash
aws s3 cp offboard-request.yaml \
  s3://fin-iam-provisioning-requests-<account_id>/requests/offboard/
```

---

### 권한 변경 (Modify)

```yaml
# modify-request.yaml
request_type: modify
request_id: MOD-20260516-001

user:
  username: lee-jb

changes:
  target_accounts:
    - dev
    - soc
  remove:
    roles:
      - Dev-Manager
  add:
    roles:
      - SOC-Analyst

request:
  requester: it-admin
  requested_at: "2026-05-16T14:00:00+09:00"
  reason: "팀 이동"
```

```bash
aws s3 cp modify-request.yaml \
  s3://fin-iam-provisioning-requests-<account_id>/requests/modify/
```

---

## 🎯 요청 시나리오

### 시나리오 1: 신규 입사자 권한 부여
- HR이 입사자 정보로 YAML 작성
- S3 업로드 → 자동으로 보안팀에 승인 요청
- 보안팀 승인 → 다중 계정에 IAM 사용자 자동 생성
- 임시 비밀번호 발급 (첫 로그인 시 변경 강제)

### 시나리오 2: 긴급 퇴사 처리
- HR이 퇴사 정보로 YAML 작성
- 즉시 모든 권한 회수
- 콘솔 로그인 차단 + Access Key 무효화
- 감사 로그에 영구 기록

### 시나리오 3: 부서 이동에 따른 권한 변경
- 매니저가 변경 요청 YAML 작성
- 양쪽 팀장 승인
- 기존 권한 자동 제거 + 신규 권한 부여

### 시나리오 4: 보안 위협 자동 차단
- 잘못된 역할 요청 (allowed_roles에 없는 역할) → 자동 거부
- 외부 도메인 이메일 요청 → 검증 단계에서 거부
- 동일 request_id 재요청 → 중복 차단

---

## 🛡️ 보안 기능

### 1. 다층 검증 시스템

```
요청 접수 → 1차 검증 → 승인 요청 → 2차 검증 → 실행
   ↓          ↓          ↓          ↓          ↓
 YAML파싱  필수필드체크  4-Eye원칙  Race방지   감사기록
```

### 2. 4-Eye Principle
- **요청자**: HR/매니저 (YAML 작성)
- **승인자**: 보안팀 (Discord에서 검토)
- **실행자**: 시스템 (자동화)
- 요청자 ≠ 승인자 강제 분리

### 3. 역할 화이트리스트
```hcl
allowed_roles = [
  "System-Admin",
  "Security-Audit",
  "Prod-Viewer",
  "Dev-Manager",
  "Stg-Manager",
  "CICD-Deploy",
  "SOC-Analyst",
  "ReadOnly"
]
```
- 목록에 없는 역할 자동 거부
- 신규 역할은 코드 변경 + 코드 리뷰 후 추가

### 4. Race Condition 방지
DynamoDB ConditionExpression으로 원자적 업데이트:
```python
ConditionExpression="status = :pending_status"
```
- 동시 요청 발생 시에도 안전
- 중복 처리 원천 차단

### 5. 봇 자동 호출 차단
Discord 봇이 링크 미리보기를 위해 자동으로 GET 요청을 보내는 것을 방지:
```python
BOT_KEYWORDS = ["discordbot", "slackbot", "facebookexternalhit", ...]
if any(keyword in user_agent for keyword in BOT_KEYWORDS):
    return "Blocked"
```

### 6. GET → POST 분리
- GET 요청: HTML 확인 페이지 반환 (실제 처리 X)
- POST 요청: 실제 승인/거부 처리
- 사용자가 명시적으로 버튼 클릭해야 처리됨

### 7. Cross-Account 보안
```
[Corp 계정]                [Target 계정]
lambda-iam-executor  →   IAMProvisioningExecutorRole
   (요청)                    (Trust + Permission)
```
- 중앙 계정에서 STS AssumeRole
- Trust Policy로 신뢰 관계 명시
- 최소 권한 원칙 적용

### 8. 감사 추적
- **DynamoDB audit_logs**: 모든 작업 영구 기록
- **CloudWatch Logs**: Lambda 실행 로그
- **Step Functions**: 워크플로우 실행 이력
- **S3 Versioning**: YAML 파일 변경 이력

---

## 📊 모니터링

### CloudWatch Logs

```bash
# 각 Lambda 로그 조회
aws logs tail /aws/lambda/fin-iam-provisioning-request-parser --since 1h
aws logs tail /aws/lambda/fin-iam-provisioning-approval-handler --since 1h
aws logs tail /aws/lambda/fin-iam-provisioning-iam-executor --since 1h
aws logs tail /aws/lambda/fin-iam-provisioning-discord-notifier --since 1h

# Step Functions 로그
aws logs tail /aws/states/fin-iam-provisioning-workflow --since 1h
```

### DynamoDB 조회

```bash
# 처리 중인 요청
aws dynamodb scan \
  --table-name fin-iam-provisioning-pending-requests \
  --max-items 10

# 감사 로그 조회
aws dynamodb scan \
  --table-name fin-iam-provisioning-audit-logs \
  --max-items 10

# 특정 사용자 이력
aws dynamodb query \
  --table-name fin-iam-provisioning-audit-logs \
  --index-name username-index \
  --key-condition-expression "username = :u" \
  --expression-attribute-values '{":u":{"S":"hong-gd"}}'

# 특정 상태 조회 (예: FAILED)
aws dynamodb query \
  --table-name fin-iam-provisioning-audit-logs \
  --index-name status-index \
  --key-condition-expression "#s = :status" \
  --expression-attribute-names '{"#s":"status"}' \
  --expression-attribute-values '{":status":{"S":"FAILED"}}'
```

### Step Functions 실행 이력

```bash
# 최근 실행 목록
aws stepfunctions list-executions \
  --state-machine-arn arn:aws:states:ap-northeast-2:<account>:stateMachine:fin-iam-provisioning-workflow \
  --max-items 10

# 특정 실행 상세
aws stepfunctions describe-execution \
  --execution-arn <execution-arn>

# 실패한 실행 필터링
aws stepfunctions list-executions \
  --state-machine-arn arn:aws:states:ap-northeast-2:<account>:stateMachine:fin-iam-provisioning-workflow \
  --status-filter FAILED
```

### IAM 사용자 확인

```bash
# 생성된 사용자 목록
aws iam list-users \
  --query "Users[?contains(Tags[?Key=='CreatedBy'].Value, 'IAMProvisioning')]"

# 특정 사용자 상세
aws iam get-user --user-name <username>
aws iam list-attached-user-policies --user-name <username>
aws iam get-login-profile --user-name <username>
```

---

## 📂 디렉토리 구조

```
terraform/iam-provisioning/
├── README.md                       # 이 파일
├── .gitignore                      # Git 제외 파일
│
├── main.tf                         # Terraform 메인
├── variables.tf                    # 변수 정의
├── outputs.tf                      # 출력 정의
├── terraform.tfvars                # 변수 값 (Git 제외)
├── terraform.tfvars.example        # 변수 예시 (Git 포함)
│
├── s3.tf                           # S3 버킷 정의
├── dynamodb.tf                     # DynamoDB 테이블
├── lambda.tf                       # Lambda 함수들
├── api-gateway.tf                  # API Gateway
├── eventbridge.tf                  # EventBridge 규칙
├── step-functions.tf               # Step Functions
├── iam-roles.tf                    # IAM Role/Policy
│
├── lambda/                         # Lambda 소스 코드
│   ├── request-parser/             # YAML 파싱 + Discord 알림
│   │   ├── index.py
│   │   ├── requirements.txt
│   │   └── yaml/                   # PyYAML 라이브러리
│   ├── approval-handler/           # 승인/거부 처리
│   │   ├── index.py
│   │   └── requirements.txt
│   ├── iam-executor/               # IAM 작업 실행
│   │   ├── index.py
│   │   └── requirements.txt
│   └── discord-notifier/           # 완료 알림
│       ├── index.py
│       └── requirements.txt
│
├── schemas/                        # YAML 스키마
│   ├── onboard.yaml
│   ├── offboard.yaml
│   └── modify.yaml
│
└── docs/                           # 문서
    ├── architecture.drawio
    └── runbook.md
```

---
