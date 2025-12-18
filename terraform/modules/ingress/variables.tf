variable "enabled" {
  description = "Whether to enable the ingress controller"
  type        = bool
  default     = true
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the EKS cluster is deployed"
  type        = string
}

variable "iam_role_arn" {
  description = "IAM role ARN for the AWS Load Balancer Controller (IRSA)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-north-1"
}

variable "namespace" {
  description = "Kubernetes namespace for the AWS Load Balancer Controller"
  type        = string
  default     = "kube-system"
}

variable "service_account_name" {
  description = "Name of the service account for AWS Load Balancer Controller"
  type        = string
  default     = "aws-load-balancer-controller"
}

variable "release_name" {
  description = "Name of the Helm release for AWS Load Balancer Controller"
  type        = string
  default     = "aws-load-balancer-controller"
}

variable "helm_chart_version" {
  description = "Version of the AWS Load Balancer Controller Helm chart. Defaults to 1.16.0 (matches v2.16.0 controller)."
  type        = string
  default     = "1.16.0"
}

variable "image_repository" {
  description = "Container image repository for AWS Load Balancer Controller. Default uses public ECR."
  type        = string
  default     = "public.ecr.aws/eks/aws-load-balancer-controller"
}

variable "image_tag" {
  description = "Container image tag for AWS Load Balancer Controller"
  type        = string
  default     = "v2.16.0"
}

variable "ingress_class" {
  description = "Ingress class name for AWS Load Balancer Controller"
  type        = string
  default     = "alb"
}

variable "create_ingress_class" {
  description = "Whether to create the IngressClass resource"
  type        = bool
  default     = true
}

variable "set_as_default_ingress_class" {
  description = "Whether to set this ingress class as the default"
  type        = bool
  default     = false
}

variable "replicas" {
  description = "Number of replicas for the AWS Load Balancer Controller deployment"
  type        = number
  default     = 2
}

variable "resources" {
  description = "Resource requests and limits for the controller pods"
  type = object({
    requests = map(string)
    limits   = map(string)
  })
  default = {
    requests = {
      cpu    = "200m"
      memory = "256Mi"
    }
    limits = {
      cpu    = "1000m"
      memory = "512Mi"
    }
  }
}

variable "extra_args" {
  description = "Extra arguments to pass to the controller"
  type        = list(string)
  default     = []
}

variable "node_selector" {
  description = "Node selector for the controller pods"
  type        = map(string)
  default     = {}
}

variable "tolerations" {
  description = "Tolerations for the controller pods"
  type = list(object({
    key      = string
    operator = string
    value    = optional(string)
    effect   = optional(string)
  }))
  default = []
}

variable "labels" {
  description = "Additional labels to apply to resources"
  type        = map(string)
  default     = {}
}

