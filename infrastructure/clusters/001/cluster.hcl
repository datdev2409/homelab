# Shared non-secret cluster configuration.
locals {
  cluster_id              = "001"
  guest_os                = "ubuntu-24.04"
  kubernetes_distribution = "k3s"
  cluster_bootstrap = {
    # https://artifacthub.io/packages/helm/argo/argo-cd
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
    lxc_templates = {
      ubuntu-24-04 = {
        url                = "http://download.proxmox.com/images/system/ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
        file_name          = "ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
        datastore_id       = "HDD-Storage"
        os_type            = "ubuntu"
        checksum           = "45c2978e6b97fe292ada95fe06834276015e5739a594db4de2fdfd830fa0c37942e8ae118fc1e32ffd9154b3f9378b592738b668ea3957db41f2907b86f219de"
        checksum_algorithm = "sha512"
      }
    }
    containers = {
      cloudflared = {
        source    = "template"
        image_key = "ubuntu-24-04"
        vm_id     = 100
        cores     = 1
        memory_mb = 512
        disk_gb   = 8
        ip_addr   = "192.168.1.100/24"
        # Budget additional RAM and verify ID/address availability before starting.
        started = true
        on_boot = true
      }
    }
    vms = {
      cp-01 = {
        role      = "control-plane"
        vm_id     = 101
        cores     = 8
        memory_mb = 14336 # 14GB ram
        disk_gb   = 100
        ip_addr   = "192.168.1.101/24"
      }
    }
  }
}
