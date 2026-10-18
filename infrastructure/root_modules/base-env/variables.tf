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
  description = "Shared VM cloud image or installer ISO. Required when vms is non-empty; omit for LXC-only deployments."
  type = object({
    mode               = optional(string, "cloud_image")
    url                = optional(string)
    local_path         = optional(string)
    file_name          = string
    datastore_id       = string
    checksum           = optional(string)
    checksum_algorithm = optional(string)
  })
  default = null
  validation {
    condition     = var.image == null ? true : (contains(["cloud_image", "installer_iso"], var.image.mode))
    error_message = "image.mode must be cloud_image or installer_iso."
  }
  validation {
    condition     = var.image == null ? true : ((var.image.url != null) != (var.image.local_path != null))
    error_message = "Set exactly one of image.url or image.local_path."
  }
  validation {
    condition     = var.image == null ? true : (var.image.url == null ? true : can(regex("^https://.+", var.image.url)))
    error_message = "image.url must be an HTTPS URL."
  }
  validation {
    condition     = var.image == null ? true : (var.image.local_path == null ? true : try(startswith(var.image.local_path, "/") && fileexists(var.image.local_path), false))
    error_message = "image.local_path must be an existing absolute file path on the OpenTofu runner."
  }
  validation {
    condition     = var.image == null ? true : (length(trimspace(var.image.datastore_id)) > 0 && can(regex(var.image.mode == "installer_iso" ? "^[^/]+[.]iso$" : "^[^/]+[.](qcow2|raw|vmdk)$", var.image.file_name)))
    error_message = "Supply a datastore and filename ending in .iso for installers or .qcow2/.raw/.vmdk for cloud images."
  }
  validation {
    condition     = var.image == null ? true : ((var.image.checksum == null && var.image.checksum_algorithm == null) || (var.image.checksum != null && contains(["sha256", "sha384", "sha512"], coalesce(var.image.checksum_algorithm, "unset"))))
    error_message = "Set checksum and checksum_algorithm together; use sha256, sha384, or sha512."
  }
  validation {
    condition     = var.image == null ? true : (var.image.local_path == null || var.image.checksum == null || var.image.checksum_algorithm == "sha256")
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
  default = {}
  validation {
    condition     = length(distinct([for vm in values(var.vms) : vm.vm_id])) == length(var.vms)
    error_message = "VM IDs must be unique."
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

variable "oci_images" {
  description = "OCI registry images pulled to Proxmox template storage, keyed for reuse by containers. Pin a version or digest for repeatable builds."
  type = map(object({
    reference    = string
    datastore_id = string
    file_name    = optional(string)
  }))
  default = {}

  validation {
    condition = alltrue([for image in values(var.oci_images) :
      length(trimspace(image.reference)) > 0 && length(trimspace(image.datastore_id)) > 0 &&
      (image.file_name == null ? true : can(regex("^[^/]+[.]tar$", image.file_name)))
    ])
    error_message = "OCI images require a registry reference, a template datastore, and an optional .tar filename without directories."
  }
}

variable "lxc_templates" {
  description = "System-container rootfs archives over HTTPS, or HTTP with a checksum, keyed for reuse by containers with source = template. Storage must allow vztmpl content."
  type = map(object({
    url                = string
    file_name          = string
    datastore_id       = string
    os_type            = optional(string, "ubuntu")
    checksum           = optional(string)
    checksum_algorithm = optional(string)
  }))
  default = {}

  validation {
    condition = alltrue([for template in values(var.lxc_templates) :
      (can(regex("^https://.+", template.url)) ||
      (can(regex("^http://.+", template.url)) && try(length(trimspace(template.checksum)) > 0, false))) &&
      can(regex("^[^/]+[.]tar[.](xz|gz|zst)$", template.file_name)) &&
      length(trimspace(template.datastore_id)) > 0
    ])
    error_message = "LXC templates require HTTPS (or HTTP with a nonempty checksum), a .tar.xz/.tar.gz/.tar.zst filename, and a datastore."
  }

  validation {
    condition = alltrue([for template in values(var.lxc_templates) :
      (template.checksum == null && template.checksum_algorithm == null) ||
      (template.checksum != null && contains(["sha256", "sha384", "sha512"], coalesce(template.checksum_algorithm, "unset")))
    ])
    error_message = "Set template checksum and checksum_algorithm together; use sha256, sha384, or sha512."
  }
}

variable "containers" {
  description = "LXC guests from OCI images or system templates. source selects the image map; system guests use root SSH and a separate inventory group."
  type = map(object({
    vm_id                 = number
    image_key             = string
    source                = optional(string, "oci")
    cores                 = number
    memory_mb             = number
    disk_gb               = number
    ip_addr               = string
    disk_storage          = optional(string)
    started               = optional(bool, false)
    on_boot               = optional(bool, false)
    entrypoint            = optional(string)
    environment_variables = optional(map(string), {})
  }))
  default = {}

  validation {
    condition     = alltrue([for ct in values(var.containers) : contains(["oci", "template"], ct.source)])
    error_message = "Container source must be oci or template."
  }

  validation {
    condition     = alltrue([for ct in values(var.containers) : ct.source != "template" || (ct.entrypoint == null && length(ct.environment_variables) == 0)])
    error_message = "entrypoint and environment_variables apply only to OCI application containers."
  }

  validation {
    condition = alltrue([for ct in values(var.containers) :
      ct.vm_id >= 100 && ct.vm_id == floor(ct.vm_id) &&
      ct.cores >= 1 && ct.cores == floor(ct.cores) &&
      ct.memory_mb >= 16 && ct.memory_mb == floor(ct.memory_mb) &&
      ct.disk_gb >= 1 && ct.disk_gb == floor(ct.disk_gb)
    ])
    error_message = "Container IDs and sizes must be integers; IDs >= 100, cores/disk >= 1, memory >= 16 MiB."
  }

  validation {
    condition     = alltrue([for ct in values(var.containers) : can(cidrnetmask(ct.ip_addr))])
    error_message = "Container addresses must be IPv4 addresses with CIDR prefixes."
  }
}
