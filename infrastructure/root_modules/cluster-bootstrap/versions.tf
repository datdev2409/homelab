terraform {
  required_version = ">= 1.8.0, < 2.0.0"

  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "= 3.3.0"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = "= 2.4.1"
    }
  }
}
