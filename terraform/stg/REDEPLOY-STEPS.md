# Stg 재배포 순서 - vuln-bank

기준 서비스: `Commando-X/vuln-bank`
리전: `ap-northeast-2`
AWS Account: `364585378962`
EKS Cluster: `fin-stg-eks`
DB: PostgreSQL RDS `fin-stg-db:5432/vulnerable_bank`

## 1. Terraform 적용

```powershell
cd "C:\Users\polis\OneDrive\Desktop\aws-cloud-security-fintech-platform-main\terraform\stg"
$env:TF_CLI_CONFIG_FILE = "C:\Users\polis\OneDrive\Desktop\aws-cloud-security-fintech-platform-main\terraform\stg\terraform-cli-empty.tfrc"
terraform init
terraform validate
terraform plan -out tfplan-base `
  -target=module.stg_vpc `
  -target=module.stg_security `
  -target=module.stg_db `
  -target=module.stg_eks `
  -target=module.stg_waf `
  -target=module.stg_iam `
  -target=module.stg_audit
terraform apply tfplan-base
```

처음 재생성할 때는 아직 Kubernetes Ingress ALB가 없으므로 Route53용 `data.aws_lb.active_ingress_alb`가 실패할 수 있습니다. 이 경우 위처럼 기본 인프라만 먼저 target apply 합니다.

이 단계에서 함께 생성되는 보안 필수 과업 리소스:

```text
IAM Groups: fin-stg-admin, fin-stg-deployer, fin-stg-auditor, fin-stg-security-ops, fin-stg-readonly
IAM Users: fin-stg-admin, fin-stg-deployer, fin-stg-auditor, fin-stg-security
MFA Policy: fin-stg-deny-without-mfa
CloudTrail: fin-stg-cloudtrail
Audit Logs: S3 fin-stg-cloudtrail-364585378962-ap-northeast-2, CloudWatch Logs /aws/cloudtrail/fin-stg-cloudtrail
Retention: 90 days
```

## 2. 이미지 빌드/푸시

```powershell
cd "C:\Users\polis\Documents\Codex\2026-05-13\files-mentioned-by-the-user-aws\vuln-bank-source"
aws ecr get-login-password --region ap-northeast-2 | docker login --username AWS --password-stdin 364585378962.dkr.ecr.ap-northeast-2.amazonaws.com
docker build -t vuln-bank:latest .
docker tag vuln-bank:latest 364585378962.dkr.ecr.ap-northeast-2.amazonaws.com/vuln-bank:latest
docker push 364585378962.dkr.ecr.ap-northeast-2.amazonaws.com/vuln-bank:latest
```

## 3. DB endpoint/secret 반영

```powershell
cd "C:\Users\polis\OneDrive\Desktop\aws-cloud-security-fintech-platform-main\terraform\stg"
$rdsHost = terraform output -raw rds_address
(Get-Content .\services\configmap.yaml -Raw) -replace 'DB_HOST: ".*"', "DB_HOST: `"$rdsHost`"" | Set-Content .\services\configmap.yaml -Encoding UTF8
.\services\sync-vuln-bank-secret.ps1
```

## 4. Kubernetes 배포

```powershell
aws eks update-kubeconfig --region ap-northeast-2 --name fin-stg-eks
kubectl apply -f .\services\configmap.yaml
kubectl apply -f .\services\vuln-bank\deployment.yaml
kubectl apply -f .\services\ingress.yaml
kubectl rollout status deployment/vuln-bank
kubectl get ingress fintech-ingress -n default
```

접속 확인:

```powershell
$albDns = kubectl get ingress fintech-ingress -n default -o jsonpath="{.status.loadBalancer.ingress[0].hostname}"
Invoke-WebRequest -Uri "http://$albDns/healthz" -UseBasicParsing
Invoke-WebRequest -Uri "http://$albDns/api/docs/" -UseBasicParsing
```

## 5. Route53 반영

Ingress가 ALB를 만든 뒤 실제 ALB 이름을 Terraform에 넘깁니다.

```powershell
$albDns = kubectl get ingress fintech-ingress -n default -o jsonpath="{.status.loadBalancer.ingress[0].hostname}"
$lbName = aws elbv2 describe-load-balancers --region ap-northeast-2 --query "LoadBalancers[?DNSName=='$albDns'].LoadBalancerName | [0]" --output text
terraform plan -out tfplan-route53 -var "active_ingress_alb_name=$lbName"
terraform apply tfplan-route53
```

## 6. 최종 검증

```powershell
terraform plan -detailed-exitcode -var "active_ingress_alb_name=$lbName"
aws cloudtrail get-trail-status --name fin-stg-cloudtrail --region ap-northeast-2
aws iam list-groups --path-prefix /fintech/stg/
aws eks list-access-entries --cluster-name fin-stg-eks --region ap-northeast-2
```

`terraform plan -detailed-exitcode` 결과가 `No changes`이면 Terraform 기준 환경은 재현 완료입니다.
