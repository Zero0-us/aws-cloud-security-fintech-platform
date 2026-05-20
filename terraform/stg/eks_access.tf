locals {
  eks_access_entries = {
    fin-stg-admin = {
      policy_arn  = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
      scope_type  = "cluster"
      namespaces  = []
      description = "Cluster admin access for the fintech platform administrator."
    }
    fin-stg-deployer = {
      policy_arn  = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"
      scope_type  = "namespace"
      namespaces  = ["default"]
      description = "Namespace edit access for application deployment."
    }
    fin-stg-auditor = {
      policy_arn  = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
      scope_type  = "namespace"
      namespaces  = ["default"]
      description = "Namespace read-only access for audit checks."
    }
    fin-stg-security = {
      policy_arn  = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
      scope_type  = "namespace"
      namespaces  = ["default"]
      description = "Namespace read-only access for security monitoring."
    }
  }
}

resource "aws_eks_access_entry" "iam_users" {
  for_each = local.eks_access_entries

  cluster_name  = module.stg_eks.cluster_name
  principal_arn = module.stg_iam.user_arns[each.key]
  type          = "STANDARD"

  tags = {
    Environment = var.env_name
    Component   = "eks-access"
    Description = each.value.description
  }

  depends_on = [
    module.stg_eks,
    module.stg_iam
  ]
}

resource "aws_eks_access_policy_association" "iam_users" {
  for_each = local.eks_access_entries

  cluster_name  = module.stg_eks.cluster_name
  policy_arn    = each.value.policy_arn
  principal_arn = module.stg_iam.user_arns[each.key]

  access_scope {
    type       = each.value.scope_type
    namespaces = each.value.scope_type == "namespace" ? each.value.namespaces : null
  }

  depends_on = [aws_eks_access_entry.iam_users]
}
