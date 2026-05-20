# Fintech stg infrastructure - vuln-bank

이 stg 환경은 기존 JOA 서비스를 제거하고, Commando-X/vuln-bank를 public fintech security testing 서비스로 배포하는 기준입니다.

## 구성

```text
User
-> Public ALB + AWS WAF
-> Kubernetes Ingress fintech-ingress
-> Service vuln-bank:5000
-> Pod vuln-bank
-> Private PostgreSQL RDS:5432
```

## 주요 리소스

- EKS Cluster: `fin-stg-eks`
- ECR Repository: `vuln-bank`
- RDS: `fin-stg-db`, PostgreSQL 16, DB name `vulnerable_bank`
- WAF: `fin-stg-waf`
- Ingress: `services/ingress.yaml`
- App manifest: `services/vuln-bank/deployment.yaml`
- IAM Groups: `fin-stg-admin`, `fin-stg-deployer`, `fin-stg-auditor`, `fin-stg-security-ops`, `fin-stg-readonly`
- IAM Users: `fin-stg-admin`, `fin-stg-deployer`, `fin-stg-auditor`, `fin-stg-security`
- MFA enforcement policy: `fin-stg-deny-without-mfa`
- CloudTrail: `fin-stg-cloudtrail`
- CloudTrail logs: S3 `fin-stg-cloudtrail-364585378962-ap-northeast-2`, CloudWatch Logs `/aws/cloudtrail/fin-stg-cloudtrail`
- EKS Access Entries: admin cluster-admin, deployer default namespace edit, auditor/security default namespace view

## 접속 경로

```text
/          -> vuln-bank web
/api/docs  -> API documentation
/graphql   -> GraphQL endpoint
/healthz   -> health check
```

## 배포 문서

자세한 순서는 `VULN-BANK-DEPLOY.md`를 따릅니다.

## IAM / Audit

Terraform now provisions the required IAM baseline for the project:

- role-based IAM groups and policies for admin, deployer, auditor, security operations, and read-only access
- sample IAM users assigned to those groups through code
- an MFA-required deny policy attached to every project IAM group
- an account password policy with 12+ characters, complexity, 90-day expiry, and reuse prevention
- CloudTrail management-event logging to S3 and CloudWatch Logs with 90-day retention
- EKS access entries that map IAM users to Kubernetes access policies

The generated IAM users do not have console passwords or access keys by default. Create credentials only for the users that will actually be used, then register MFA before using AWS services.
