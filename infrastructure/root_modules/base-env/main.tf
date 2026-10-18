locals {
  is_cloud_image = var.image == null ? false : var.image.mode == "cloud_image"
  media_id       = length(var.vms) == 0 || var.image == null ? null : var.image.url != null ? proxmox_virtual_environment_download_file.media[0].id : proxmox_virtual_environment_file.media[0].id
}

resource "proxmox_virtual_environment_download_file" "media" {
  count              = length(var.vms) > 0 && try(var.image.url != null, false) ? 1 : 0
  node_name          = var.proxmox_node
  datastore_id       = var.image.datastore_id
  content_type       = local.is_cloud_image ? "import" : "iso"
  url                = var.image.url
  file_name          = var.image.file_name
  checksum           = var.image.checksum
  checksum_algorithm = var.image.checksum_algorithm
}

resource "proxmox_virtual_environment_file" "media" {
  count        = length(var.vms) > 0 && try(var.image.local_path != null, false) ? 1 : 0
  node_name    = var.proxmox_node
  datastore_id = var.image.datastore_id
  content_type = local.is_cloud_image ? "import" : "iso"
  # Do not silently take ownership of an existing unmanaged file.
  overwrite = false
  source_file {
    path      = var.image.local_path
    file_name = var.image.file_name
    checksum  = var.image.checksum
  }
}

resource "proxmox_virtual_environment_vm" "nodes" {
  for_each = var.vms

  node_name   = var.proxmox_node
  vm_id       = each.value.vm_id
  name        = "${var.name_prefix}-${each.key}"
  description = "Kubernetes homelab VM managed by OpenTofu;"
  tags        = ["terraform", "kubernetes"]

  bios          = "seabios"
  scsi_hardware = "virtio-scsi-single"
  started       = each.value.started
  on_boot       = each.value.on_boot

  boot_order = !local.is_cloud_image && each.value.installer_attached && each.value.boot_from_installer ? ["ide3", "scsi0"] : ["scsi0"]

  dynamic "cdrom" {
    for_each = local.is_cloud_image ? [] : [1]
    content {
      interface = "ide3"
      file_id   = each.value.installer_attached ? local.media_id : "none"
    }
  }

  lifecycle {
    precondition {
      condition     = !local.is_cloud_image || can(regex("^(ssh-|ecdsa-)", trimspace(var.ssh_public_key)))
      error_message = "Cloud-image mode requires an OpenSSH public key for cloud-init."
    }
  }

  cpu {
    cores   = each.value.cores
    sockets = 1
    type    = "host"
  }

  memory {
    dedicated = each.value.memory_mb
    floating  = 0
  }

  # Disabled initially: the OS and guest agent are not installed yet.
  agent {
    enabled = try(each.value.guest_agent_enabled, false)
  }

  disk {
    datastore_id = coalesce(each.value.disk_storage, var.vm_disk_storage)
    interface    = "scsi0"
    import_from  = local.is_cloud_image ? local.media_id : null
    file_format  = "raw"
    size         = each.value.disk_gb
    discard      = "on"
    iothread     = true
  }

  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }

  operating_system {
    type = "l26"
  }

  dynamic "initialization" {
    for_each = local.is_cloud_image ? [1] : []
    content {
      datastore_id = coalesce(each.value.disk_storage, var.vm_disk_storage)

      user_account {
        username = var.cloud_init_user
        keys     = [trimspace(var.ssh_public_key)]
      }

      ip_config {
        ipv4 {
          address = each.value.ip_addr
          gateway = var.network_gateway
        }
      }

      dns {
        servers = [var.dns_server]
      }
    }
  }
}
