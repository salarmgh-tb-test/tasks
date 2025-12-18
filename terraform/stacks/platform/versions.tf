# -----------------------------------------------------------------------------
# Terraform and Provider Version Constraints
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
      configuration_aliases = [github.frontend]
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

