variable "eks_version" {
  description = "Optional EKS Kubernetes version. Leave null to let AWS choose the current default supported version."
  type        = string
  default     = null
}

variable "eks_control_plane_log_types" {
  description = "EKS control plane log types to send to CloudWatch Logs."
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

resource "aws_cloudwatch_log_group" "eks_cluster" {
  name              = "/aws/eks/fin-dev-eks/cluster"
  retention_in_days = var.audit_log_retention_days

  tags = {
    Name = "fin-dev-eks-control-plane-logs"
  }
}

resource "aws_iam_role" "eks_cluster" {
  name = "fin-dev-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "fin-dev-eks-cluster-role"
  }
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_eks_cluster" "dev" {
  name                      = "fin-dev-eks"
  version                   = var.eks_version
  role_arn                  = aws_iam_role.eks_cluster.arn
  enabled_cluster_log_types = var.eks_control_plane_log_types

  vpc_config {
    subnet_ids = [
      aws_subnet.dev_pri_2a.id,
      aws_subnet.dev_pri_2c.id,
      aws_subnet.dev_pub_2a.id,
      aws_subnet.dev_pub_2c.id,
    ]

    security_group_ids      = [aws_security_group.eks_cluster_additional.id]
    endpoint_public_access  = true
    endpoint_private_access = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_cloudwatch_log_group.eks_cluster,
  ]

  tags = {
    Name = "fin-dev-eks"
  }
}

resource "aws_iam_role" "eks_node" {
  name = "fin-dev-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "fin-dev-eks-node-role"
  }
}

resource "aws_iam_role_policy_attachment" "eks_worker" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node.name
}

resource "aws_iam_role_policy_attachment" "eks_cni" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node.name
}

resource "aws_iam_role_policy_attachment" "ecr_readonly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node.name
}

resource "aws_eks_node_group" "dev_spot" {
  cluster_name    = aws_eks_cluster.dev.name
  node_group_name = "fin-dev-nodegroup"
  node_role_arn   = aws_iam_role.eks_node.arn

  subnet_ids = [
    aws_subnet.dev_pri_2a.id,
    aws_subnet.dev_pri_2c.id,
  ]

  capacity_type  = "SPOT"
  instance_types = ["t3.small"]
  ami_type       = "AL2_x86_64"
  disk_size      = 20

  scaling_config {
    desired_size = 1
    min_size     = 1
    max_size     = 2
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker,
    aws_iam_role_policy_attachment.eks_cni,
    aws_iam_role_policy_attachment.ecr_readonly,
  ]

  tags = {
    Name = "fin-dev-nodegroup"
  }
}
