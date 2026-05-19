# Fintech Dev Environment

This folder creates the dev cloud environment for the vuln-bank fintech web app.

## Current design

```text
Internet
-> Public ALB fin-dev-alb
-> Target Group fin-dev-tg
-> EKS managed node group fin-dev-nodegroup
-> Kubernetes NodePort Service vuln-bank:30080
-> vuln-bank Pod:5000
-> Private PostgreSQL RDS fin-dev-db
```

## Why dev is different from prod

Prod uses the production Terraform structure and can be extended with Kubernetes Ingress/ALB Controller patterns.

Dev keeps the public web path simpler:

- Terraform creates the ALB directly.
- Terraform attaches the EKS node group Auto Scaling Group to the ALB target group.
- Kubernetes exposes vuln-bank with fixed NodePort `30080`.
- Route53 and VPC peering are disabled by default so they do not block basic web deployment.

## Main files

- `vpc.tf`: VPC, public/private/DB subnets, NAT, route tables
- `eks.tf`: EKS cluster and spot node group
- `alb.tf`: public ALB, target group, listener, node group attachment
- `rds.tf`: private PostgreSQL RDS and generated password
- `ecr.tf`: ECR repository for the vuln-bank image
- `waf.tf`: WAF in count mode for web security testing
- `audit.tf`: CloudTrail, VPC Flow Logs, AWS Config, WAF logging, and CloudWatch export role
- `services/`: Kubernetes ConfigMap, Secret sync script, and vuln-bank Deployment/Service
- `DEV-DEPLOY-STEPS.md`: step-by-step deployment guide

## Audit and logging

Dev follows the architecture workbook's separate Dev account model:

- CloudTrail: `fin-dev-cloudtrail`
- CloudTrail logs: `fin-dev-log-s3/soc-logs/cloudtrail/dev`
- VPC Flow Logs: `/aws/vpc/flowlogs/fin-dev-vpc`
- AWS Config: `fin-dev-config-recorder`
- AWS Config delivery: `fin-dev-log-s3/soc-logs/config/dev`
- WAF Logs: `aws-waf-logs-fin-dev-waf`
- CloudWatch export role: `fin-cloudwatch-export-role`

Apply `terraform/soc` first or otherwise prepare the SOC log bucket/KMS policy so the Dev account can deliver CloudTrail, AWS Config, WAF, and ALB logs.

## Optional settings

DNS is disabled unless both values are set:

```hcl
dev_domain_name = "dev.example.com"
dev_zone_name   = "example.com"
```

VPC peering is disabled unless these values are set:

```hcl
enable_vpc_peering = true
peer_vpc_id        = "vpc-xxxxxxxx"
peer_owner_id      = "123456789012"
peer_vpc_cidr      = "10.10.0.0/16"
```
