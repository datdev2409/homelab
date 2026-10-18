locals {
  ansible_inventory = {
    all = {
      vars = {
        ansible_user               = var.cloud_init_user
        ansible_python_interpreter = "/usr/bin/python3"
      }
      hosts = merge(
        { for name, vm in var.vms : name => { ansible_host = split("/", vm.ip_addr)[0] } },
        { for name, ct in var.containers : name => { ansible_host = split("/", ct.ip_addr)[0], ansible_user = "root" } if ct.source == "template" }
      )
      children = {
        control_plane     = { hosts = { for name, vm in var.vms : name => {} if vm.role == "control-plane" } }
        system_containers = { hosts = { for name, ct in var.containers : name => {} if ct.source == "template" } }
        workers           = { hosts = { for name, vm in var.vms : name => {} if vm.role == "worker" } }
      }
    }
  }
}

resource "local_file" "ansible_inventory" {
  filename             = var.inventory_path
  content              = yamlencode(local.ansible_inventory)
  file_permission      = "0600"
  directory_permission = "0700"
  depends_on           = [proxmox_virtual_environment_vm.nodes, proxmox_virtual_environment_container.this]

  lifecycle {
    precondition {
      condition     = length(var.vms) + length(var.containers) > 0
      error_message = "Provide at least one VM or container."
    }
    precondition {
      condition     = length(var.vms) == 0 || var.image != null
      error_message = "VM provisioning requires image. Omit image only for LXC-only deployments."
    }
    precondition {
      condition     = length(distinct(concat([for vm in values(var.vms) : vm.vm_id], [for ct in values(var.containers) : ct.vm_id]))) == length(var.vms) + length(var.containers)
      error_message = "VMs and containers share a Proxmox ID namespace; all IDs must be unique."
    }
    precondition {
      condition     = length(distinct(concat([for vm in values(var.vms) : split("/", vm.ip_addr)[0]], [for ct in values(var.containers) : split("/", ct.ip_addr)[0]]))) == length(var.vms) + length(var.containers)
      error_message = "VMs and containers must have unique IPv4 addresses."
    }
    precondition {
      condition     = length(setintersection(toset(keys(var.vms)), toset(keys(var.containers)))) == 0
      error_message = "VM and container names must be unique to avoid duplicate hostnames."
    }
  }
}
