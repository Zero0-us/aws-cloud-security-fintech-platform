## [Concept] Terraform Outputs for Integration
## Purpose: 생성된 EKS 리소스 정보를 외부 모듈(Helm, Kubectl 등)에 전달하기 위한 접점 정의
## Usage: 타 모듈에서 'module.eks_infrastructure.cluster_name' 형태로 참조

## 1. 클러스터 식별 정보
output "cluster_name" {
  description = "EKS 클러스터 이름"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS 클러스터 API 서버 엔드포인트"
  value       = module.eks.cluster_endpoint
}

## 2. 보안 및 인증 정보
output "cluster_certificate_authority_data" {
  description = "EKS 클러스터와 통신하기 위한 Base64 인코딩된 인증서 데이터"
  value       = module.eks.cluster_certificate_authority_data
}

## 3. IRSA (IAM Roles for Service Accounts) 정보
output "alb_controller_role_arn" {
  description = "ALB Controller가 AWS API를 호출하기 위해 사용할 IAM Role의 ARN (루트의 Helm 릴리즈에서 참조)"
  value       = module.alb_controller_irsa_role.iam_role_arn

  # FIXME: Role 생성 모듈이 실패하면 Helm 배포가 깨질 수 있으므로 의존성 체크 필수
}

# ============================================================
# 적용 후 검증 체크리스트
# ============================================================
# 1. 노드 상태 확인
#    kubectl get nodes
#
# 2. 전체 파드 상태 확인
#    kubectl get pods -A
#
# 3. EBS CSI 드라이버 애드온 상태 확인
#    kubectl get pods -n kube-system -l app=ebs-csi-controller
#    aws eks describe-addon --cluster-name <cluster_name> --addon-name aws-ebs-csi-driver
#
# 4. AWS Load Balancer Controller 상태 확인
#    kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
#    kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
