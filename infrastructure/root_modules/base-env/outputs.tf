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

output "containers" {
  description = "LXC IDs, image sources, and desired addresses; guest readiness must be verified."
  value = { for name, ct in var.containers : name => {
    vm_id      = proxmox_virtual_environment_container.this[name].vm_id
    image_key  = ct.image_key
    source     = ct.source
    ip_addr    = ct.ip_addr
    ip_address = split("/", ct.ip_addr)[0]
  } }
}

output "oci_image_ids" {
  description = "Pulled OCI template volume IDs keyed by image name."
  value       = { for name, image in proxmox_oci_image.this : name => image.id }
}

output "lxc_template_ids" {
  description = "Downloaded system-container template volume IDs keyed by template name."
  value       = { for name, template in proxmox_download_file.lxc_template : name => template.id }
}
