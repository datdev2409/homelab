output "vms" {
  description = "Provisioned VM metadata for subsequent cluster configuration."
  value = { for name, vm in var.vms : name => {
    vm_id      = proxmox_virtual_environment_vm.nodes[name].vm_id
    role       = vm.role
    ip_addr    = vm.ip_addr
    ip_address = split("/", vm.ip_addr)[0]
  } }
}

output "image_id" {
  value = local.media_id
}

output "ansible_inventory" {
  description = "Desired inventory; ISO guests must be configured before Ansible can connect."
  value       = local.ansible_inventory
}

output "inventory_file" {
  description = "Absolute path to the inventory file managed by OpenTofu."
  value       = local_file.ansible_inventory.filename
}

output "public_key" {
  value = trimspace(var.ssh_public_key)
}
