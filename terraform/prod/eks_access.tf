locals {
  eks_access_entries = {
    fin-prod-admin = {
      policy_arn  = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
      scope_type  = "cluster"
      namespaces  = []
      description = "Cluster admin access for the fintech platform administrator."
    }
    fin-prod-deployer = {
      policy_arn  = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"
      scope_type  = "namespace"
      namespaces  = ["default"]
      description = "Namespace edit access for application deployment."
    }
    fin-prod-auditor = {
      policy_arn  = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
      scope_type  = "namespace"
      namespaces  = ["default"]
      description = "Namespace read-only access for audit checks."
    }
    fin-prod-security = {
      policy_arn  = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
      scope_type  = "namespace"
      namespaces  = ["default"]
      description = "Namespace read-only access for security monitoring."
    }
  }
}

resource "aws_eks_access_entry" "iam_users" {
  for_each = local.eks_access_entries

  cluster_name  = module.prod_eks.cluster_name
  principal_arn = module.prod_iam.user_arns[each.key]
  type          = "STANDARD"

  tags = {
    Environment = var.env_name
    Component   = "eks-access"
    Description = each.value.description
  }

  depends_on = [
    module.prod_eks,
    module.prod_iam
  ]
}

resource "aws_eks_access_policy_association" "iam_users" {
  for_each = local.eks_access_entries

  cluster_name  = module.prod_eks.cluster_name
  policy_arn    = each.value.policy_arn
  principal_arn = module.prod_iam.user_arns[each.key]

  access_scope {
    type       = each.value.scope_type
    namespaces = each.value.scope_type == "namespace" ? each.value.namespaces : null
  }

  depends_on = [aws_eks_access_entry.iam_users]
}
