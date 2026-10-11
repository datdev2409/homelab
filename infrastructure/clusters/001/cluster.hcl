# Shared non-secret cluster configuration.
locals {
  cluster_id              = "001"
  guest_os                = "ubuntu-24.04"
  kubernetes_distribution = "kubeadm"
  cluster_bootstrap = {
    argocd_chart_version = "10.10.2"
    argocd_namespace     = "argocd"
    argocd_release_name  = "argocd"
    applications = [
      {
        application_name = "root-001"
        repo_url         = "https://github.com/datdev2409/homelab.git"
        ref              = "main"
        path             = "apps/roots/001"
      }
    ]
  }
  base_env = {
    virtual_environment_endpoint = "https://192.168.1.200:8006"
    # Preserve current host's self-signed TLS behavior explicitly.
    insecure_tls    = true
    proxmox_node    = "pve"
    name_prefix     = "k8s-homelab"
    vm_disk_storage = "local-lvm"
    network_bridge  = "vmbr0"
    network_gateway = "192.168.1.1"
    dns_server      = "1.1.1.1"
    cloud_init_user = "ubuntu"
    image = {
      mode         = "cloud_image"
      url          = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
      file_name    = "ubuntu-24.04-cloudimg-amd64.qcow2"
      datastore_id = "local" # Keep local to match with existing states, the correct place to put cloud-images should be "HDD-Storage"
    }
    vms = {
      cp-01 = {
        role      = "control-plane"
        vm_id     = 201
        cores     = 3
        memory_mb = 5120
        disk_gb   = 16
        ip_addr   = "192.168.1.201/24"
      }
      worker-01 = {
        role      = "worker"
        vm_id     = 202
        cores     = 2
        memory_mb = 4096
        disk_gb   = 16
        ip_addr   = "192.168.1.202/24"
      }
      worker-02 = {
        role      = "worker"
        vm_id     = 203
        cores     = 2
        memory_mb = 4096
        disk_gb   = 16
        ip_addr   = "192.168.1.203/24"
      }
    }
  }
}
