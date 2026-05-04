# aws-cloud-security-fintech-platform

AWS 기반 핀테크 보안 플랫폼 — KT Cloud 프로젝트

## 프로젝트 개요

AWS 멀티 계정 환경(Audit/SOC, Dev, Stg, Prod)에서 EKS 기반 핀테크 서비스를 운영하며,
보안 로그 수집·분석·대응 체계를 구축하는 클라우드 보안 아키텍처 프로젝트입니다.

## 기술 스택

- **IaC**: Terraform
- **Container**: AWS EKS (Kubernetes)
- **Backend**: Spring Boot 3.2 (JPA, Spring Security)
- **Frontend**: Next.js 14, React
- **DB**: MySQL 8.0 (RDS), Redis
- **Security**: GuardDuty, CloudTrail, Athena, WAF, KMS
- **CI/CD**: ECR, ALB Ingress Controller

## Acknowledgments / 출처 표기

본 프로젝트의 핀테크 애플리케이션은
[JOA OpenAPI](https://github.com/rheeeuro/joa-openapi) (SSAFY 10기 프로젝트)를 기반으로 하며,
**원작자의 사용 허락을 받았습니다.**

### 사용 범위
- **Spring Boot 백엔드 3개** (bank-backend, openapi-backend, admin-backend): JOA 원본 코드를 AWS EKS 배포용으로 사용
- **Next.js 프론트엔드 2개** (admin-frontend, docs-frontend): JOA 원본 코드를 사용
- **bank-web** (뱅킹 웹): JOA의 React Native 모바일 앱을 Next.js 웹으로 변환
- **DB 스키마**: JOA의 MySQL 스키마를 사용
- **API 구조/모델**: JOA의 API 엔드포인트 및 데이터 모델을 사용

### 본 프로젝트의 독자적 작업 범위
- AWS 멀티 계정 보안 아키텍처 설계 (Audit/SOC, Dev, Stg, Prod)
- Terraform IaC 전체 (VPC, EKS, RDS, ALB, SG, KMS, VPC Peering 등)
- 보안 파이프라인 (GuardDuty, CloudTrail, Athena, Config, SecurityHub)
- K8s 매니페스트 (Deployment, Service, Ingress, ConfigMap, Secrets)
- CI/CD 및 ECR 구성
- 아키텍처 설계 문서 (drawio, xlsx)