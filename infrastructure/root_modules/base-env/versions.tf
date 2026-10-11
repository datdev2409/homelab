terraform {
  required_version = ">= 1.8.0, < 2.0.0"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "= 2.9.1"
    }
    proxmox = {
      source  = "bpg/proxmox"
      version = "= 0.115.0"
    }
  }
}
