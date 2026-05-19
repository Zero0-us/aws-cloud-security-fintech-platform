# AWS Cloud Security Fintech Platform

핀테크 웹 서비스를 AWS 기반 클라우드 환경에 배포하고, IAM, 네트워크, 감사 로그, 컴플라이언스 관점의 보안 구성을 Terraform으로 구현하는 프로젝트입니다.

## 프로젝트 개요

이 저장소는 취약점 점검용 핀테크 웹 애플리케이션을 Dev, Stg, Prod 환경에 배포하고, SOC 계정에서 보안 로그를 중앙 수집하는 구조를 목표로 합니다.

현재 애플리케이션 기준은 `vuln-bank`입니다.

- Workload: vuln-bank
- Runtime: EKS, Kubernetes
- Database: Amazon RDS PostgreSQL
- Image Registry: Amazon ECR
- Public Entry: ALB
- Security: IAM, MFA, Security Group, WAF, KMS, CloudTrail, VPC Flow Logs, AWS Config, CloudWatch Logs
- SOC: 중앙 S3 로그 저장소, Athena, Lambda, SNS, EventBridge 기반 분석 및 알림 구조

## Terraform 구조

```text
terraform/
  dev/              Dev 계정용 인프라 및 vuln-bank 배포 설정
  stg/              Stage 환경 인프라
  prod/             Prod 계정용 인프라 및 vuln-bank 배포 설정
  soc/              SOC 계정용 중앙 로그 저장 및 분석 인프라
  iam-provisioning/ IAM 사용자, 그룹, MFA 정책 자동화 구성
```

## 현재 구현 범위

### Dev

- VPC, Public/Private/DB Subnet
- NAT Gateway, Internet Gateway, Route Table
- EKS Cluster, Node Group
- ECR Repository: `vuln-bank-dev`
- RDS PostgreSQL
- ALB, Target Group, Listener
- WAF Web ACL
- CloudTrail, VPC Flow Logs, AWS Config
- WAF Logs, EKS Control Plane Logs, CloudWatch Logs Export Role
- Kubernetes manifest for vuln-bank
- Optional Route53
- VPC Peering은 기본 비활성화

### Prod

- VPC, Public/Private/DB Subnet
- EKS Cluster, Node Group
- ECR Repository: `vuln-bank`
- RDS PostgreSQL
- Kubernetes Ingress 기반 Public ALB
- WAF Web ACL
- IAM 그룹/사용자/MFA 정책
- CloudTrail, VPC Flow Logs, AWS Config
- CloudWatch Logs Export Role
- SOC 중앙 S3 로그 전달 구조
- VPC Peering은 제외

### SOC

- 중앙 로그 저장용 S3
- KMS 기반 로그 암호화
- Athena 분석 기반
- Lambda, SNS, EventBridge를 통한 보안 이벤트 처리 구조
- Workload 계정의 CloudTrail, Config, ALB, WAF, CloudWatch Logs Export 연동 대상

## 배포 흐름

기본 흐름은 아래 순서입니다.

```text
Terraform 인프라 생성
-> ECR 이미지 빌드/푸시
-> Kubernetes manifest 적용
-> ALB 또는 Ingress 생성
-> WAF/Route53 연결
-> CloudTrail, VPC Flow Logs, AWS Config, CloudWatch Logs로 감사 로그 수집
-> SOC 계정에서 로그 저장/분석/알림
```

환경별 상세 명령은 각 Terraform 폴더의 배포 문서를 참고합니다.

- `terraform/dev/DEV-DEPLOY-STEPS.md`
- `terraform/prod/REDEPLOY-STEPS.md`
- `terraform/prod/VULN-BANK-DEPLOY.md`

## 보안 설계 기준

이 프로젝트는 다음 필수 과업을 Terraform 코드로 구현하는 것을 목표로 합니다.

- 서비스별 보안 그룹 및 네트워크 격리
- RDS 암호화 및 Private Subnet 배치
- IAM 최소 권한 그룹/정책 구성
- MFA 의무화 정책
- CloudTrail 기반 API 감사 로그
- VPC Flow Logs 기반 네트워크 흐름 로그
- AWS Config 기반 규정 준수 점검
- WAF 기반 웹 요청 보호
- CloudWatch Logs 기반 로그 보관 및 SOC Export
- SOC 중앙 S3 기반 장기 로그 저장

## 주의 사항

- 이 저장소에는 실제 비밀번호, AWS Access Key, Secret Key를 커밋하지 않습니다.
- DB 비밀번호는 Terraform의 `random_password`와 AWS Secrets Manager로 생성/보관합니다.
- `terraform.tfvars`에는 민감 정보가 들어갈 수 있으므로 커밋하지 않습니다.
- `terraform.tfvars.example`은 예시 값만 포함합니다.
- ALB DNS, Target Group ARN, RDS Endpoint 등은 재생성 시 바뀔 수 있습니다.

## 애플리케이션 출처

현재 테스트 워크로드는 핀테크 취약점 점검용 웹 애플리케이션인 `vuln-bank`를 기준으로 구성합니다.

- Source: https://github.com/Commando-X/vuln-bank

이 저장소의 주요 작업 범위는 애플리케이션 자체 개발이 아니라, 해당 서비스를 AWS 클라우드 보안 아키텍처 위에 배포하고 감사/보안/컴플라이언스 체계를 구성하는 것입니다.
