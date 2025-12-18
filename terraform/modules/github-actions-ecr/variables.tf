#--------------------------------------------------------------
# GitHub Actions ECR IAM User Module Variables
#--------------------------------------------------------------

variable "user_name" {
  description = "Name of the IAM user for GitHub Actions ECR access"
  type        = string
  default     = "github-actions-ecr"

  validation {
    condition     = can(regex("^[a-zA-Z0-9+=,.@_-]+$", var.user_name))
    error_message = "IAM user name must be a valid IAM user name (alphanumeric and special characters: +=,.@_-)."
  }
}

variable "user_path" {
  description = "Path for the IAM user"
  type        = string
  default     = "/"
}

variable "aws_region" {
  description = "AWS region where ECR repositories are located"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.aws_region))
    error_message = "AWS region must be a valid AWS region identifier."
  }
}

variable "ecr_repositories" {
  description = "List of ECR repository names to grant access to"
  type        = list(string)
  default     = ["backend"]

  validation {
    condition     = length(var.ecr_repositories) > 0
    error_message = "At least one ECR repository must be specified."
  }
}

variable "create_access_key" {
  description = "Whether to create an access key for the user. Set to false if you want to create keys manually or use a different method."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to the IAM user"
  type        = map(string)
  default     = {}
}

#--------------------------------------------------------------
# EKS Access Variables (Optional)
#--------------------------------------------------------------
variable "enable_eks_access" {
  description = "Whether to grant EKS cluster access for kubectl/helm deployments"
  type        = bool
  default     = false
}

variable "eks_cluster_arns" {
  description = "List of EKS cluster ARNs to grant access to (required if enable_eks_access is true)"
  type        = list(string)
  default     = []
}

#--------------------------------------------------------------
# RDS Access Variables (Optional)
#--------------------------------------------------------------
variable "enable_rds_access" {
  description = "Whether to grant RDS instance access for querying database information"
  type        = bool
  default     = false
}

variable "rds_instance_arns" {
  description = "List of RDS instance ARNs to grant access to. If empty, grants access to all RDS instances (use with caution)"
  type        = list(string)
  default     = []
}

