# Stg destroy 순서

이 문서는 비용 방지를 위해 stg 환경을 내리는 순서입니다.

기준 서비스: `Commando-X/vuln-bank`
리전: `ap-northeast-2`
AWS Account: `364585378962`
Terraform 폴더: `C:\Users\polis\OneDrive\Desktop\aws-cloud-security-fintech-platform-main\terraform\stg`

## 1. 현재 계정 확인

```powershell
cd "C:\Users\polis\OneDrive\Desktop\aws-cloud-security-fintech-platform-main\terraform\stg"
aws sts get-caller-identity
```

정상 계정:

```text
Account: 364585378962
```

## 2. Kubernetes 앱 리소스 먼저 삭제

EKS Ingress가 만든 ALB는 Kubernetes 리소스를 삭제해야 함께 내려갑니다.

```powershell
aws eks update-kubeconfig --region ap-northeast-2 --name fin-stg-eks
kubectl delete -f .\services\ingress.yaml --ignore-not-found
kubectl delete -f .\services\vuln-bank\deployment.yaml --ignore-not-found
kubectl delete -f .\services\configmap.yaml --ignore-not-found
```

ALB가 사라졌는지 확인합니다.

```powershell
kubectl get ingress fintech-ingress -n default
aws elbv2 describe-load-balancers --region ap-northeast-2 --names k8s-default-fintechi-961c886429
```

`LoadBalancerNotFound`가 나오면 삭제된 것입니다.

## 3. Terraform destroy 실행

```powershell
$env:TF_CLI_CONFIG_FILE = "C:\Users\polis\OneDrive\Desktop\aws-cloud-security-fintech-platform-main\terraform\stg\terraform-cli-empty.tfrc"
terraform init
terraform plan -destroy -out tfplan-destroy
terraform apply tfplan-destroy
```

삭제 대상에는 VPC, NAT Gateway, EKS, NodeGroup, RDS PostgreSQL, WAF, Route53, IAM 사용자/그룹/정책, CloudTrail, CloudTrail S3 bucket, CloudWatch Logs가 포함됩니다.

## 4. 잔여 과금 리소스 확인

```powershell
aws eks list-clusters --region ap-northeast-2
aws rds describe-db-instances --region ap-northeast-2 --query "DBInstances[?DBInstanceIdentifier=='fin-stg-db'].DBInstanceStatus"
aws ec2 describe-nat-gateways --region ap-northeast-2 --filter "Name=tag:Name,Values=fin-stg-nat" --query "NatGateways[].State"
aws elbv2 describe-load-balancers --region ap-northeast-2 --query "LoadBalancers[?contains(LoadBalancerName,'k8s-default-fintechi')].[LoadBalancerName,DNSName]"
aws cloudtrail describe-trails --region ap-northeast-2 --trail-name-list fin-stg-cloudtrail
aws s3api head-bucket --bucket fin-stg-cloudtrail-364585378962-ap-northeast-2
```

리소스가 없다는 오류가 나오면 정상적으로 삭제된 것입니다.

## 5. 다음 재배포

다음에 같은 환경을 다시 열 때는 `REDEPLOY-STEPS.md`를 따릅니다.
