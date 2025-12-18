data "aws_caller_identity" "current" {}

#--------------------------------------------------------------
# EKS Cluster
#--------------------------------------------------------------
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
    # If public access enabled and no CIDRs specified, default to 0.0.0.0/0
    # Otherwise use the provided CIDRs (or empty if public access disabled)
    public_access_cidrs     = var.endpoint_public_access ? (length(var.public_access_cidrs) > 0 ? var.public_access_cidrs : ["0.0.0.0/0"]) : []
    security_group_ids      = [aws_security_group.cluster.id]
  }

  enabled_cluster_log_types = var.enabled_log_types

  tags = merge(var.tags, {
    Name = var.cluster_name
  })

  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSVPCResourceController,
  ]

  lifecycle {
    precondition {
      condition     = length(var.subnet_ids) >= 2
      error_message = "EKS requires at least 2 subnets in different availability zones for high availability."
    }
    precondition {
      condition     = var.endpoint_private_access || var.endpoint_public_access
      error_message = "At least one of endpoint_private_access or endpoint_public_access must be enabled."
    }
  }
}

#--------------------------------------------------------------
# Cluster IAM Role
#--------------------------------------------------------------
resource "aws_iam_role" "cluster" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.cluster.name
}

#--------------------------------------------------------------
# Cluster Security Group
#--------------------------------------------------------------
resource "aws_security_group" "cluster" {
  name        = "${var.cluster_name}-cluster-sg"
  description = "Security group for EKS cluster control plane"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-cluster-sg"
  })
}

#--------------------------------------------------------------
# OIDC Provider for IRSA
#--------------------------------------------------------------
data "tls_certificate" "cluster" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "cluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = var.tags
}

#--------------------------------------------------------------
# EKS Add-ons (control plane - no nodes required)
#--------------------------------------------------------------
# VPC CNI and kube-proxy run on control plane, don't need nodes
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                 = aws_eks_cluster.main.name
  addon_name                   = "vpc-cni"
  addon_version                = var.vpc_cni_version
  resolve_conflicts_on_create  = "OVERWRITE"
  resolve_conflicts_on_update  = "OVERWRITE"

  tags = var.tags
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                 = aws_eks_cluster.main.name
  addon_name                   = "kube-proxy"
  addon_version                = var.kube_proxy_version
  resolve_conflicts_on_create  = "OVERWRITE"
  resolve_conflicts_on_update  = "OVERWRITE"

  tags = var.tags
}

# NOTE: CoreDNS and EBS CSI Driver are created at environment level
# because they need nodes to schedule pods. See environments/dev/main.tf

#--------------------------------------------------------------
# EBS CSI Driver IAM Role (created here, addon created at env level)
#--------------------------------------------------------------
resource "aws_iam_role" "ebs_csi" {
  count = var.enable_ebs_csi_driver ? 1 : 0

  name = "${var.cluster_name}-ebs-csi-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.cluster.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
            "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  count = var.enable_ebs_csi_driver ? 1 : 0

  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi[0].name
}

###############################################################
# (end of file)
###############################################################

