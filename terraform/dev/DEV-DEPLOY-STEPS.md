# Dev vuln-bank deployment steps

This dev environment publishes the vuln-bank web app through a Terraform-managed public ALB.

Flow:

```text
User
-> fin-dev-alb
-> ALB target group fin-dev-tg
-> EKS node NodePort 30080
-> Kubernetes Service vuln-bank
-> vuln-bank Pod port 5000
-> PostgreSQL RDS fin-dev-db
```

## 1. Create dev infrastructure

```powershell
cd "C:\Users\polis\OneDrive\Desktop\aws-cloud-security-fintech-platform-main\terraform\dev"
terraform init
terraform validate
terraform plan -out tfplan-dev
terraform apply tfplan-dev
```

Main resources:

```text
VPC/Subnets/NAT
EKS fin-dev-eks
ECR vuln-bank-dev
RDS PostgreSQL fin-dev-db
Secrets Manager fin-dev-db-password-v2
ALB fin-dev-alb
WAF fin-dev-waf
CloudTrail fin-dev-cloudtrail
VPC Flow Logs /aws/vpc/flowlogs/fin-dev-vpc
AWS Config fin-dev-config-recorder
CloudWatch Export Role fin-cloudwatch-export-role
```

Before applying, make sure the SOC account has prepared `fin-dev-log-s3` and its bucket/KMS policies for this separate Dev account.

## 2. Build and push vuln-bank image

```powershell
cd "C:\Users\polis\Documents\Codex\2026-05-13\files-mentioned-by-the-user-aws\vuln-bank-source"
$accountId = aws sts get-caller-identity --query Account --output text
$repo = "$accountId.dkr.ecr.ap-northeast-2.amazonaws.com/vuln-bank-dev:latest"
aws ecr get-login-password --region ap-northeast-2 | docker login --username AWS --password-stdin "$accountId.dkr.ecr.ap-northeast-2.amazonaws.com"
docker build -t vuln-bank-dev:latest .
docker tag vuln-bank-dev:latest $repo
docker push $repo
```

If the AWS account is not `364585378962`, update the image value in `services\vuln-bank\deployment.yaml`.

## 3. Connect kubectl to dev EKS

```powershell
aws eks update-kubeconfig --region ap-northeast-2 --name fin-dev-eks
kubectl get nodes
```

Continue after the node is `Ready`.

## 4. Put RDS connection values into Kubernetes

```powershell
cd "C:\Users\polis\OneDrive\Desktop\aws-cloud-security-fintech-platform-main\terraform\dev"
$rdsHost = terraform output -raw rds_address
(Get-Content .\services\configmap.yaml -Raw) -replace 'DB_HOST: ".*"', "DB_HOST: `"$rdsHost`"" | Set-Content .\services\configmap.yaml -Encoding UTF8
.\services\sync-vuln-bank-secret.ps1
```

## 5. Deploy vuln-bank

```powershell
kubectl apply -f .\services\configmap.yaml
kubectl apply -f .\services\vuln-bank\deployment.yaml
kubectl rollout status deployment/vuln-bank
kubectl get pods
kubectl get svc
```

## 6. Open the web app

```powershell
$albDns = terraform output -raw alb_dns_name
Invoke-WebRequest -Uri "http://$albDns/healthz" -UseBasicParsing
```

Browser URLs:

```text
http://<ALB_DNS>/
http://<ALB_DNS>/graphql
http://<ALB_DNS>/sup3r_s3cr3t_admin
```

## 7. Useful checks

```powershell
kubectl logs deployment/vuln-bank
kubectl describe pod -l app=vuln-bank
aws elbv2 describe-target-health --region ap-northeast-2 --target-group-arn <TARGET_GROUP_ARN>
```

## 8. Destroy when finished

```powershell
kubectl delete -f .\services\vuln-bank\deployment.yaml --ignore-not-found
kubectl delete -f .\services\configmap.yaml --ignore-not-found
kubectl delete secret vuln-bank-secrets -n default --ignore-not-found
terraform destroy
```
