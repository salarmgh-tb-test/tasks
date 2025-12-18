#--------------------------------------------------------------
# GitHub Actions ECR IAM User Module
#--------------------------------------------------------------
# This module creates an IAM user with minimal permissions
# to push/pull Docker images to/from Amazon ECR for GitHub Actions CI/CD
#--------------------------------------------------------------

#--------------------------------------------------------------
# IAM User
#--------------------------------------------------------------
resource "aws_iam_user" "github_actions_ecr" {
  name = var.user_name
  path = var.user_path

  tags = merge(
    var.tags,
    {
      Name        = var.user_name
      Purpose     = "GitHub Actions ECR Access"
      ManagedBy   = "Terraform"
    }
  )
}

#--------------------------------------------------------------
# IAM Policy for ECR Access
#--------------------------------------------------------------
resource "aws_iam_user_policy" "github_actions_ecr" {
  name = "${var.user_name}-ecr-policy"
  user = aws_iam_user.github_actions_ecr.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRAuthentication"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Sid    = "ECRRepositoryAccess"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = [
          for repo in var.ecr_repositories : "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/${repo}"
        ]
      },
      {
        Sid    = "ECRDescribeRepositories"
        Effect = "Allow"
        Action = [
          "ecr:DescribeRepositories",
          "ecr:DescribeImages",
          "ecr:ListImages"
        ]
        Resource = [
          for repo in var.ecr_repositories : "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/${repo}"
        ]
      },
      {
        Sid    = "ECRCreateRepository"
        Effect = "Allow"
        Action = [
          "ecr:CreateRepository",
          "ecr:TagResource"
        ]
        Resource = [
          for repo in var.ecr_repositories : "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/${repo}"
        ]
        # Note: Condition removed to allow repository creation via AWS CLI
        # Repository name is already restricted to specific repositories in the Resource list
      },
      {
        Sid    = "GetCallerIdentity"
        Effect = "Allow"
        Action = [
          "sts:GetCallerIdentity"
        ]
        Resource = "*"
      }
    ]
  })
}

#--------------------------------------------------------------
# IAM Policy for EKS Access (Optional)
#--------------------------------------------------------------
resource "aws_iam_user_policy" "eks_access" {
  count = var.enable_eks_access ? 1 : 0
  name  = "${var.user_name}-eks-policy"
  user  = aws_iam_user.github_actions_ecr.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EKSDescribeCluster"
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster"
        ]
        Resource = var.eks_cluster_arns
      }
    ]
  })
}

#--------------------------------------------------------------
# IAM Policy for RDS Access (Optional)
#--------------------------------------------------------------
resource "aws_iam_user_policy" "rds_access" {
  count = var.enable_rds_access ? 1 : 0
  name  = "${var.user_name}-rds-policy"
  user  = aws_iam_user.github_actions_ecr.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RDSDescribeInstances"
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances",
          "rds:DescribeDBClusters"
        ]
        # DescribeDBInstances requires * resource to list/query instances
        # This is a read-only operation and is safe
        Resource = "*"
      },
      {
        Sid    = "RDSListTags"
        Effect = "Allow"
        Action = [
          "rds:ListTagsForResource"
        ]
        Resource = length(var.rds_instance_arns) > 0 ? var.rds_instance_arns : ["*"]
      }
    ]
  })
}

#--------------------------------------------------------------
# Access Keys (Optional)
#--------------------------------------------------------------
resource "aws_iam_access_key" "github_actions_ecr" {
  count = var.create_access_key ? 1 : 0
  user  = aws_iam_user.github_actions_ecr.name
}

#--------------------------------------------------------------
# Data Sources
#--------------------------------------------------------------
data "aws_caller_identity" "current" {}

