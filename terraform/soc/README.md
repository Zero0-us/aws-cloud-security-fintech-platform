# SOC / Audit Account Terraform

이 Terraform은 핀테크 클라우드 보안 플랫폼에서 **SOC / Audit Account** 영역을 구성한다.

목표는 Production / Development 계정의 서비스 운영 리소스를 직접 만드는 것이 아니라, 각 계정에서 발생하는 감사 로그와 보안 이벤트를 중앙 수집하고, 규제 준수 상태를 점검하며, Athena로 분석할 수 있는 SOC 기반을 준비하는 것이다.

## 구현 범위

현재 구현된 주요 구성은 다음과 같다.

```text
SOC / Audit Account
├─ Audit VPC
├─ Bastion Subnet 2a/2c
├─ Peering/TGW 연결용 Subnet 2a/2c
├─ Internet Gateway
├─ Route Tables
├─ Bastion EC2
├─ KMS CMK
├─ S3 Buckets
│  ├─ SOC audit log bucket
│  ├─ SOC compliance bucket
│  └─ SOC Athena results bucket
├─ CloudTrail
├─ AWS Config
├─ VPC Flow Logs
├─ Athena / Glue Catalog
├─ AWS Config Managed Rules
├─ EventBridge
├─ SNS Notification
├─ GuardDuty optional
└─ Security Hub optional
```

EKS, NodeGroup, ALB, RDS, 운영 애플리케이션, AML/거래 원본 데이터 버킷은 이 SOC Terraform의 범위가 아니다. 해당 리소스는 Production / Development 담당 영역에서 구성한다.

## SOC 버킷 설계

SOC 계정에는 보안 관제와 감사 목적의 버킷만 둔다.

```text
fin-soc-audit-log-<suffix>
fin-soc-compliance-<suffix>
fin-soc-athena-results-<suffix>
```

### `fin-soc-audit-log-<suffix>`

중앙 감사 로그 저장소다.

저장 대상:

- CloudTrail
- VPC Flow Logs
- AWS Config delivery
- WAF Logs
- ALB Access Logs
- 관리자 접근 기록
- 보안 이벤트 로그

Production / Development 계정의 CloudTrail, Config, Flow Logs도 이 버킷으로 적재하도록 연동한다.

### `fin-soc-compliance-<suffix>`

감사 및 규제 준수 산출물을 저장한다.

저장 대상:

- 월간 감사보고서
- ISMS-P 점검 결과
- 규제 준수 점검표
- 제출용 증거자료
- 인시던트 리뷰 산출물

### `fin-soc-athena-results-<suffix>`

SOC Athena 조회 결과를 저장한다.

기본 Workgroup 결과 위치:

```text
s3://fin-soc-athena-results-<suffix>/sc-audit/
```

Prefix 기준 lifecycle:

```text
ops/                 30일 후 삭제
sc-audit/            90일 후 Standard-IA, 1년 후 Glacier
incident/            90일 후 Standard-IA, 1년 후 Glacier
compliance-result/   90일 후 Standard-IA
```

## 다른 계정과의 역할 분리

SOC 계정에 모든 애플리케이션 데이터를 저장하지 않는다.

SOC 계정에 저장하는 것:

- 감사 로그
- 보안 로그
- 설정 변경 이력
- 네트워크 흐름 로그
- 보안 분석 결과
- 컴플라이언스 증빙

Production 계정에 저장하는 것:

- 전자금융거래 원본 기록
- AML 원본 자료
- DB 백업
- 애플리케이션 업무 데이터
- 운영 Athena 결과

Development 계정에 저장하는 것:

- 테스트 데이터
- 개발용 비운영 산출물

즉, SOC는 운영 원본 데이터의 소유자가 아니라 **중앙 로그/감사/관제 허브** 역할을 한다.

## Dev / Prod 연동 시 필요한 값

나중에 VPC Peering과 Cross-account 로그 적재를 연결할 때 `terraform.tfvars`에 아래 값을 넣는다.

```hcl
prod_vpc_peering_connection_id = "pcx-..."
dev_vpc_peering_connection_id  = "pcx-..."

prod_account_id = "111122223333"
dev_account_id  = "444455556666"
```

SOC 쪽에서 이 값들을 넣으면:

- SOC Route Table에 Prod / Dev CIDR route가 추가된다.
- SOC S3 bucket policy가 Prod / Dev 로그 적재를 허용한다.
- SOC KMS key policy가 Prod / Dev 로그 서비스의 KMS 사용을 허용한다.

Prod / Dev 쪽에서도 반대 방향 route가 필요하다.

```text
Prod/Dev route table
→ 10.10.0.0/16
→ SOC VPC Peering Connection
```

## 로그 적재 방식

Prod / Dev 계정은 별도의 로그 버킷을 만들기보다 SOC audit log bucket으로 로그를 보낸다.

연동 대상:

- CloudTrail destination bucket
- AWS Config delivery channel
- VPC Flow Logs S3 destination
- ALB Access Logs
- WAF Logs
- EKS Audit Logs, 필요 시

Athena는 Prod나 Dev VPC에 직접 붙는 것이 아니라, SOC S3 버킷에 적재된 로그 파일을 조회한다.

```text
Prod / Dev Logs
→ SOC audit log bucket
→ Glue Catalog / Athena
→ SOC Athena results bucket
```

## KMS 구성

현재 KMS는 EKS용이 아니라 SOC 로그 암호화용이다.

사용처:

- SOC S3 buckets SSE-KMS
- CloudTrail log encryption
- AWS Config delivery encryption
- VPC Flow Logs S3 delivery encryption
- Athena query result encryption

EKS NodeGroup / EBS 암호화를 구성할 경우에는 별도의 EKS/EBS KMS key를 만드는 것이 좋다. EKS Managed NodeGroup에서 EBS 암호화 KMS를 사용할 때는 Auto Scaling service-linked role에 KMS 권한이 필요하다.

## 규제 준수 모니터링

AWS Config Managed Rule을 통해 기본 보안 준수 상태를 점검한다.

포함된 점검:

- CloudTrail 활성화 여부
- S3 public read 차단 여부
- S3 public write 차단 여부
- S3 server-side encryption 활성화 여부
- VPC Flow Logs 활성화 여부
- SSH `0.0.0.0/0` 허용 여부
- IAM User MFA 활성화 여부
- Root Account MFA 활성화 여부

NON_COMPLIANT 상태 변경은 EventBridge를 통해 SNS Topic으로 전달된다.

## 정기 감사 자동화

현재 구현된 자동화:

- 매월 1일 EventBridge schedule 실행
- SOC 감사 SNS Topic으로 월간 감사 보고서 작성 알림 발송
- Athena named query로 월간 CloudTrail 활동 요약 쿼리 제공
- 보고서 보관 위치로 SOC compliance bucket 사용

아직 구현하지 않은 부분:

- Lambda가 Athena 쿼리를 직접 실행
- 결과를 Markdown / CSV / HTML 보고서로 생성
- 보고서를 compliance bucket에 저장
- 보고서 링크를 담당자에게 자동 발송

향후 Lambda를 추가하면 완전한 월간 보고서 자동화가 가능하다.

## 알림 이메일 설정

`terraform.tfvars`에서 이메일을 설정하면 SNS 구독이 생성된다.

```hcl
audit_notification_email = "your-email@example.com"
```

AWS에서 구독 확인 메일이 발송되며, 수신자가 Confirm 해야 알림이 실제로 전달된다.

## 실행 방법

```bash
terraform init
terraform validate
terraform plan
terraform apply
```

개인 환경값은 `terraform.tfvars.example`을 참고해 `terraform.tfvars`를 로컬에서 만들어 사용한다.

## GitHub에 올리면 안 되는 파일

아래 파일은 민감 정보나 로컬 상태를 포함할 수 있으므로 커밋하지 않는다.

```text
terraform.tfvars
terraform.tfstate
terraform.tfstate.backup
.terraform/
*.tfplan
.venv/
.DS_Store
```

특히 `terraform.tfstate`에는 실제 AWS 계정 ID, ARN, KMS ARN, 버킷명 등이 포함될 수 있다.

공유는 `terraform.tfvars.example`만 사용한다.
