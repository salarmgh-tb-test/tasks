variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.cluster_name))
    error_message = "Cluster name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "cluster_version" {
  description = "Kubernetes version for the cluster"
  type        = string
  default     = "1.34"

  validation {
    condition     = can(regex("^1\\.(2[5-9]|[3-9][0-9])$", var.cluster_version))
    error_message = "Cluster version must be 1.25 or higher."
  }
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the EKS cluster"
  type        = list(string)

  # Allow single subnet for dev, but recommend 2+ for HA
  validation {
    condition     = length(var.subnet_ids) >= 1
    error_message = "At least 1 subnet is required (use 2+ for production)."
  }
}

variable "endpoint_private_access" {
  description = "Enable private API server endpoint"
  type        = bool
  default     = true
}

variable "endpoint_public_access" {
  description = "Enable public API server endpoint"
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "CIDR blocks allowed to access public endpoint. Empty list = 0.0.0.0/0 when public access enabled."
  type        = list(string)
  default     = []  # Empty for most secure default - restricts to VPC only when endpoint_public_access is false

  validation {
    condition     = alltrue([for cidr in var.public_access_cidrs : can(cidrhost(cidr, 0))])
    error_message = "All public_access_cidrs must be valid CIDR blocks."
  }
}

variable "enabled_log_types" {
  description = "List of control plane log types to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "log_retention_days" {
  description = "Retention period for CloudWatch logs"
  type        = number
  default     = 30
}

variable "enable_ebs_csi_driver" {
  description = "Enable EBS CSI driver add-on"
  type        = bool
  default     = true
}

variable "vpc_cni_version" {
  description = "Version of VPC CNI add-on"
  type        = string
  default     = "v1.21.0-eksbuild.4"
}

variable "kube_proxy_version" {
  description = "Version of kube-proxy add-on"
  type        = string
  default     = "v1.34.1-eksbuild.2"
}

# NOTE: coredns_version and ebs_csi_version are defined at environment level
# because those addons require nodes and are created after node groups

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

