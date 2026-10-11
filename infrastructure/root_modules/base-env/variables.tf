variable "virtual_environment_endpoint" {
  description = "Proxmox API URL."
  type        = string
}

variable "virtual_environment_api_token" {
  description = "Optional API token; otherwise use PROXMOX_VE_API_TOKEN. Never commit it."
  type        = string
  default     = null
  sensitive   = true
}

variable "insecure_tls" {
  description = "Explicitly accept an untrusted Proxmox TLS certificate."
  type        = bool
  default     = false
}

variable "proxmox_node" {
  type = string
}

variable "name_prefix" {
  type = string
}

variable "vm_disk_storage" {
  description = "Default storage for active VM disks and cloud-init disks."
  type        = string
  default     = "local-lvm"
}

variable "network_bridge" {
  type    = string
  default = "vmbr0"
}

variable "network_gateway" {
  type = string
  validation {
    condition     = can(cidrnetmask("${var.network_gateway}/32"))
    error_message = "network_gateway must be an IPv4 address."
  }
}

variable "dns_server" {
  type    = string
  default = "1.1.1.1"
}

variable "cloud_init_user" {
  type    = string
  default = "ubuntu"
}

variable "ssh_public_key" {
  description = "Public key content, not a path relative to Terragrunt's cache."
  type        = string
  default     = ""
  validation {
    condition     = var.ssh_public_key == "" || can(regex("^(ssh-|ecdsa-)", trimspace(var.ssh_public_key)))
    error_message = "Provide an OpenSSH public key."
  }
}

variable "image" {
  description = "Shared cloud image or installer ISO. Choose exactly one HTTPS URL or absolute local file path."
  type = object({
    mode               = optional(string, "cloud_image")
    url                = optional(string)
    local_path         = optional(string)
    file_name          = string
    datastore_id       = string
    checksum           = optional(string)
    checksum_algorithm = optional(string)
  })
  validation {
    condition     = contains(["cloud_image", "installer_iso"], var.image.mode)
    error_message = "image.mode must be cloud_image or installer_iso."
  }
  validation {
    condition     = (var.image.url != null) != (var.image.local_path != null)
    error_message = "Set exactly one of image.url or image.local_path."
  }
  validation {
    condition     = var.image.url == null ? true : can(regex("^https://.+", var.image.url))
    error_message = "image.url must be an HTTPS URL."
  }
  validation {
    condition     = var.image.local_path == null ? true : try(startswith(var.image.local_path, "/") && fileexists(var.image.local_path), false)
    error_message = "image.local_path must be an existing absolute file path on the OpenTofu runner."
  }
  validation {
    condition     = length(trimspace(var.image.datastore_id)) > 0 && can(regex(var.image.mode == "installer_iso" ? "^[^/]+[.]iso$" : "^[^/]+[.](qcow2|raw|vmdk)$", var.image.file_name))
    error_message = "Supply a datastore and filename ending in .iso for installers or .qcow2/.raw/.vmdk for cloud images."
  }
  validation {
    condition     = (var.image.checksum == null && var.image.checksum_algorithm == null) || (var.image.checksum != null && contains(["sha256", "sha384", "sha512"], coalesce(var.image.checksum_algorithm, "unset")))
    error_message = "Set checksum and checksum_algorithm together; use sha256, sha384, or sha512."
  }
  validation {
    condition     = var.image.local_path == null || var.image.checksum == null || var.image.checksum_algorithm == "sha256"
    error_message = "Local uploads support SHA256 checksums only."
  }
}

variable "vms" {
  description = "VM layout keyed by stable inventory name. role groups Kubernetes nodes in inventory; other roles are allowed."
  type = map(object({
    role                = string
    vm_id               = number
    cores               = number
    memory_mb           = number
    disk_gb             = number
    ip_addr             = string
    started             = optional(bool, true)
    on_boot             = optional(bool, true)
    guest_agent_enabled = optional(bool, false)
    disk_storage        = optional(string)
    installer_attached  = optional(bool, true)
    boot_from_installer = optional(bool, true)
  }))
  validation {
    condition     = length(var.vms) > 0 && length(distinct([for vm in values(var.vms) : vm.vm_id])) == length(var.vms)
    error_message = "Provide at least one VM with unique VM IDs."
  }
  validation {
    condition     = alltrue([for vm in values(var.vms) : vm.vm_id >= 100 && vm.vm_id == floor(vm.vm_id) && vm.cores >= 1 && vm.cores == floor(vm.cores) && vm.memory_mb >= 512 && vm.memory_mb == floor(vm.memory_mb) && vm.disk_gb >= 1 && vm.disk_gb == floor(vm.disk_gb)])
    error_message = "VM IDs and resource sizes must be positive integers; IDs >= 100 and memory >= 512 MiB."
  }
  validation {
    condition     = alltrue([for vm in values(var.vms) : can(cidrnetmask(vm.ip_addr))]) && length(distinct([for vm in values(var.vms) : split("/", vm.ip_addr)[0]])) == length(var.vms)
    error_message = "VM addresses must be unique IPv4 addresses with CIDR prefixes."
  }
}

variable "inventory_path" {
  description = "Absolute inventory destination on the runner, supplied by the cluster unit rather than derived from the module cache."
  type        = string
  validation {
    condition     = startswith(var.inventory_path, "/") && endswith(var.inventory_path, "/inventory.yml")
    error_message = "inventory_path must be an absolute path ending in /inventory.yml."
  }
}
