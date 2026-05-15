# Vuln-bank prod deployment

This prod setup replaces the previous JOA services with Commando-X/vuln-bank.

## Architecture

User -> Public ALB + WAF -> Kubernetes Ingress fintech-ingress -> Service vuln-bank:5000 -> Pod vuln-bank -> Private PostgreSQL RDS:5432

## Terraform

```powershell
cd "C:\Users\polis\OneDrive\Desktop\aws-cloud-security-fintech-platform-main\terraform\prod"
terraform init
terraform validate
terraform plan -out tfplan-vuln-bank
terraform apply tfplan-vuln-bank
```

The RDS engine changes from MySQL 8.0 to PostgreSQL 16. This replaces the old database.

Terraform also creates the IAM and audit baseline:

- IAM groups: `fin-prod-admin`, `fin-prod-deployer`, `fin-prod-auditor`, `fin-prod-security-ops`, `fin-prod-readonly`
- IAM users: `fin-prod-admin`, `fin-prod-deployer`, `fin-prod-auditor`, `fin-prod-security`
- MFA-required policy: `fin-prod-deny-without-mfa`
- CloudTrail: `fin-prod-cloudtrail`
- Audit log storage: S3 `fin-prod-cloudtrail-364585378962-ap-northeast-2`, CloudWatch Logs `/aws/cloudtrail/fin-prod-cloudtrail`

## Build and push image

```powershell
cd "C:\Users\polis\Documents\Codex\2026-05-13\files-mentioned-by-the-user-aws\vuln-bank-source"
aws ecr get-login-password --region ap-northeast-2 | docker login --username AWS --password-stdin 364585378962.dkr.ecr.ap-northeast-2.amazonaws.com
docker build -t vuln-bank:latest .
docker tag vuln-bank:latest 364585378962.dkr.ecr.ap-northeast-2.amazonaws.com/vuln-bank:latest
docker push 364585378962.dkr.ecr.ap-northeast-2.amazonaws.com/vuln-bank:latest
```

## Update Kubernetes config from Terraform outputs

After Terraform apply, set the RDS endpoint in the ConfigMap if it changed.

```powershell
$rdsHost = terraform output -raw rds_address
(Get-Content .\services\configmap.yaml -Raw) -replace 'DB_HOST: ".*"', "DB_HOST: `"$rdsHost`"" | Set-Content .\services\configmap.yaml -Encoding UTF8
```

Sync the RDS password from Secrets Manager into Kubernetes.

```powershell
.\services\sync-vuln-bank-secret.ps1
```

## Deploy to EKS

```powershell
aws eks update-kubeconfig --region ap-northeast-2 --name fin-prod-eks
kubectl apply -f .\services\configmap.yaml
kubectl apply -f .\services\vuln-bank\deployment.yaml
kubectl apply -f .\services\ingress.yaml
kubectl rollout status deployment/vuln-bank
kubectl get ingress fintech-ingress -n default
```

## Public paths

```text
/          -> vuln-bank web
/api/docs  -> API documentation
/graphql   -> GraphQL endpoint
/healthz   -> health check
```

## Route53 phase

After Ingress creates the ALB, get the physical ALB name and pass it to Terraform.

```powershell
$albDns = kubectl get ingress fintech-ingress -n default -o jsonpath="{.status.loadBalancer.ingress[0].hostname}"
$lbName = aws elbv2 describe-load-balancers --region ap-northeast-2 --query "LoadBalancers[?DNSName=='$albDns'].LoadBalancerName | [0]" --output text
terraform plan -out tfplan-route53 -var "active_ingress_alb_name=$lbName"
terraform apply tfplan-route53
```
