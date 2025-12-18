#--------------------------------------------------------------
# IAM Module Variables
#--------------------------------------------------------------

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.cluster_name))
    error_message = "Cluster name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "oidc_provider_arn" {
  description = "ARN of the OIDC provider for the EKS cluster"
  type        = string

  validation {
    condition     = can(regex("^arn:aws:iam::[0-9]+:oidc-provider/", var.oidc_provider_arn))
    error_message = "OIDC provider ARN must be a valid IAM OIDC provider ARN."
  }
}

variable "oidc_provider_url" {
  description = "URL of the OIDC provider (without https://)"
  type        = string
}

#--------------------------------------------------------------
# Controller Toggles
#--------------------------------------------------------------

variable "enable_cluster_autoscaler" {
  description = "Create IAM role for Cluster Autoscaler"
  type        = bool
  default     = true
}

variable "enable_load_balancer_controller" {
  description = "Create IAM role for AWS Load Balancer Controller"
  type        = bool
  default     = true
}

variable "load_balancer_controller_namespace" {
  description = "Namespace where AWS Load Balancer Controller is deployed"
  type        = string
  default     = "kube-system"
}

variable "load_balancer_controller_service_account" {
  description = "Service account name for AWS Load Balancer Controller"
  type        = string
  default     = "aws-load-balancer-controller"
}

variable "enable_external_dns" {
  description = "Create IAM role for External DNS"
  type        = bool
  default     = false
}

#--------------------------------------------------------------
# Application Service Accounts
#--------------------------------------------------------------

variable "service_accounts" {
  description = "Map of service accounts to create IRSA roles for"
  type = map(object({
    namespace       = string
    service_account = string
    policy_json     = string
  }))
  default = {}

  # Example:
  # service_accounts = {
  #   backend = {
  #     namespace       = "production"
  #     service_account = "backend-sa"
  #     policy_json     = jsonencode({
  #       Version = "2012-10-17"
  #       Statement = [
  #         {
  #           Effect   = "Allow"
  #           Action   = ["s3:GetObject", "s3:PutObject"]
  #           Resource = "arn:aws:s3:::my-bucket/*"
  #         }
  #       ]
  #     })
  #   }
  # }
}

#--------------------------------------------------------------
# Tags
#--------------------------------------------------------------

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
