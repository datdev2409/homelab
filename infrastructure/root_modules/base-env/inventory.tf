locals {
  ansible_inventory = {
    all = {
      vars = {
        ansible_user               = var.cloud_init_user
        ansible_python_interpreter = "/usr/bin/python3"
      }
      hosts = { for name, vm in var.vms : name => { ansible_host = split("/", vm.ip_addr)[0] } }
      children = {
        control_plane = { hosts = { for name, vm in var.vms : name => {} if vm.role == "control-plane" } }
        workers       = { hosts = { for name, vm in var.vms : name => {} if vm.role == "worker" } }
      }
    }
  }
}

resource "local_file" "ansible_inventory" {
  filename             = var.inventory_path
  content              = yamlencode(local.ansible_inventory)
  file_permission      = "0600"
  directory_permission = "0700"
  depends_on           = [proxmox_virtual_environment_vm.nodes]
}
