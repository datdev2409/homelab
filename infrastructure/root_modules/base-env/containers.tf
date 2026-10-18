resource "proxmox_download_file" "lxc_template" {
  for_each = var.lxc_templates

  node_name           = var.proxmox_node
  datastore_id        = each.value.datastore_id
  content_type        = "vztmpl"
  url                 = each.value.url
  file_name           = each.value.file_name
  checksum            = each.value.checksum
  checksum_algorithm  = each.value.checksum_algorithm
  overwrite_unmanaged = false
}

resource "proxmox_oci_image" "this" {
  for_each = var.oci_images

  node_name           = var.proxmox_node
  datastore_id        = each.value.datastore_id
  reference           = each.value.reference
  file_name           = each.value.file_name
  overwrite_unmanaged = false
}

resource "proxmox_virtual_environment_container" "this" {
  for_each = var.containers

  node_name             = var.proxmox_node
  vm_id                 = each.value.vm_id
  description           = "LXC container managed by OpenTofu"
  tags                  = ["terraform", each.value.source == "oci" ? "oci" : "system"]
  unprivileged          = true
  started               = each.value.started
  start_on_boot         = each.value.on_boot
  environment_variables = each.value.environment_variables

  lifecycle {
    precondition {
      condition     = contains(each.value.source == "oci" ? keys(var.oci_images) : keys(var.lxc_templates), each.value.image_key)
      error_message = "Container image_key must reference the map selected by source: oci_images or lxc_templates."
    }
    precondition {
      condition     = each.value.source != "template" || can(regex("^(ssh-|ecdsa-)", trimspace(var.ssh_public_key)))
      error_message = "System-template containers require an OpenSSH public key for root access."
    }
  }

  cpu {
    cores = each.value.cores
  }

  dynamic "features" {
    for_each = each.value.source == "template" ? [1] : []
    content {
      nesting = true
    }
  }

  memory {
    dedicated = each.value.memory_mb
    swap      = 0
  }

  disk {
    datastore_id = coalesce(each.value.disk_storage, var.vm_disk_storage)
    size         = each.value.disk_gb
  }

  operating_system {
    template_file_id = each.value.source == "oci" ? try(proxmox_oci_image.this[each.value.image_key].id, null) : try(proxmox_download_file.lxc_template[each.value.image_key].id, null)
    type             = each.value.source == "oci" ? "unmanaged" : try(var.lxc_templates[each.value.image_key].os_type, "ubuntu")
  }

  initialization {
    hostname   = "${var.name_prefix}-${each.key}"
    entrypoint = each.value.entrypoint

    dynamic "user_account" {
      for_each = each.value.source == "template" ? [1] : []
      content {
        keys = [trimspace(var.ssh_public_key)]
      }
    }

    dns {
      servers = [var.dns_server]
    }

    ip_config {
      ipv4 {
        address = each.value.ip_addr
        gateway = var.network_gateway
      }
    }
  }

  network_interface {
    name         = "eth0"
    bridge       = var.network_bridge
    host_managed = each.value.source == "oci"
  }
}
