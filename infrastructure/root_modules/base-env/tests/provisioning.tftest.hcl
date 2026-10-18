# All providers are mocked: these tests never create guests or write inventory.
mock_provider "proxmox" {
  mock_resource "proxmox_download_file" {
    defaults = { id = "templates:vztmpl/ubuntu.tar.xz" }
  }
  mock_resource "proxmox_oci_image" {
    defaults = { id = "templates:vztmpl/web.tar" }
  }
  mock_resource "proxmox_virtual_environment_download_file" {
    defaults = { id = "templates:iso/test.iso" }
  }
}

mock_provider "local" {}

variables {
  virtual_environment_endpoint = "https://pve.example.invalid:8006/"
  proxmox_node                 = "pve"
  name_prefix                  = "test"
  network_gateway              = "192.0.2.1"
  inventory_path               = "/tmp/homelab-oci-test/inventory.yml"
  ssh_public_key               = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITestOnly"
  oci_images = {
    web = {
      reference    = "docker.io/library/nginx:1.28-alpine"
      datastore_id = "templates"
    }
  }
  containers = {
    web = {
      vm_id     = 200
      image_key = "web"
      cores     = 1
      memory_mb = 256
      disk_gb   = 2
      ip_addr   = "192.0.2.20/24"
    }
  }
}

run "lxc_only" {
  command = plan

  assert {
    condition     = output.image_id == null && length(output.vms) == 0
    error_message = "LXC-only deployments must not require or provision VM media."
  }
  assert {
    condition     = length(output.ansible_inventory.all.hosts) == 0 && output.containers.web.ip_address == "192.0.2.20"
    error_message = "OCI applications must not become Kubernetes Ansible hosts."
  }
  assert {
    condition     = !proxmox_virtual_environment_container.this["web"].started && !proxmox_virtual_environment_container.this["web"].start_on_boot && proxmox_virtual_environment_container.this["web"].unprivileged
    error_message = "New OCI containers must default to stopped, no boot startup, and unprivileged."
  }
}

run "mixed_guests" {
  command = plan

  variables {
    image = {
      url          = "https://example.invalid/ubuntu.qcow2"
      file_name    = "ubuntu.qcow2"
      datastore_id = "templates"
    }
    vms = {
      cp = {
        role      = "control-plane"
        vm_id     = 100
        cores     = 2
        memory_mb = 2048
        disk_gb   = 16
        ip_addr   = "192.0.2.10/24"
      }
    }
  }

  assert {
    condition     = keys(output.ansible_inventory.all.hosts) == ["cp"] && keys(output.ansible_inventory.all.children.control_plane.hosts) == ["cp"]
    error_message = "Adding OCI containers must preserve VM inventory membership."
  }
}

run "vm_only_installer" {
  command = plan

  variables {
    containers     = {}
    oci_images     = {}
    ssh_public_key = ""
    image = {
      mode         = "installer_iso"
      url          = "https://example.invalid/ubuntu.iso"
      file_name    = "ubuntu.iso"
      datastore_id = "templates"
    }
    vms = {
      cp = {
        role      = "control-plane"
        vm_id     = 100
        cores     = 2
        memory_mb = 2048
        disk_gb   = 16
        ip_addr   = "192.0.2.10/24"
      }
    }
  }

  assert {
    condition     = length(output.containers) == 0 && proxmox_virtual_environment_vm.nodes["cp"].boot_order == tolist(["ide3", "scsi0"])
    error_message = "VM-only installer behavior must remain supported without an SSH key."
  }
}

run "duplicate_container_id" {
  command = plan

  variables {
    containers = {
      first = {
        vm_id = 200, image_key = "web", cores = 1, memory_mb = 256, disk_gb = 2, ip_addr = "192.0.2.20/24"
      }
      second = {
        vm_id = 200, image_key = "web", cores = 1, memory_mb = 256, disk_gb = 2, ip_addr = "192.0.2.21/24"
      }
    }
  }

  expect_failures = [local_file.ansible_inventory]
}

run "duplicate_container_address" {
  command = plan

  variables {
    containers = {
      first = {
        vm_id = 200, image_key = "web", cores = 1, memory_mb = 256, disk_gb = 2, ip_addr = "192.0.2.20/24"
      }
      second = {
        vm_id = 201, image_key = "web", cores = 1, memory_mb = 256, disk_gb = 2, ip_addr = "192.0.2.20/25"
      }
    }
  }

  expect_failures = [local_file.ansible_inventory]
}

run "unknown_image" {
  command = plan

  variables {
    oci_images = {}
  }

  expect_failures = [proxmox_virtual_environment_container.this]
}

run "empty_deployment" {
  command = plan

  variables {
    containers = {}
    oci_images = {}
  }

  expect_failures = [local_file.ansible_inventory]
}

run "cross_guest_id_collision" {
  command = plan

  variables {
    image = {
      url          = "https://example.invalid/ubuntu.qcow2"
      file_name    = "ubuntu.qcow2"
      datastore_id = "templates"
    }
    vms = {
      cp = {
        role      = "control-plane"
        vm_id     = 200
        cores     = 2
        memory_mb = 2048
        disk_gb   = 16
        ip_addr   = "192.0.2.10/24"
      }
    }
  }

  expect_failures = [local_file.ansible_inventory]
}

run "vm_requires_media" {
  command = plan

  variables {
    image = null
    vms = {
      cp = {
        role      = "control-plane"
        vm_id     = 100
        cores     = 2
        memory_mb = 2048
        disk_gb   = 16
        ip_addr   = "192.0.2.10/24"
      }
    }
  }

  expect_failures = [local_file.ansible_inventory]
}

run "ubuntu_system_container" {
  command = plan

  variables {
    oci_images = {}
    lxc_templates = {
      ubuntu = {
        url                = "http://example.invalid/ubuntu.tar.xz"
        file_name          = "ubuntu.tar.xz"
        datastore_id       = "templates"
        checksum           = "45c2978e6b97fe292ada95fe06834276015e5739a594db4de2fdfd830fa0c37942e8ae118fc1e32ffd9154b3f9378b592738b668ea3957db41f2907b86f219de"
        checksum_algorithm = "sha512"
      }
    }
    containers = {
      cloudflared = {
        source = "template", image_key = "ubuntu", vm_id = 204,
        cores  = 1, memory_mb = 512, disk_gb = 8, ip_addr = "192.0.2.204/24"
      }
    }
  }

  assert {
    condition     = output.ansible_inventory.all.hosts.cloudflared.ansible_user == "root" && keys(output.ansible_inventory.all.children.system_containers.hosts) == ["cloudflared"]
    error_message = "System containers must use root SSH in a dedicated inventory group."
  }
  assert {
    condition     = length(output.ansible_inventory.all.children.control_plane.hosts) == 0 && length(output.ansible_inventory.all.children.workers.hosts) == 0
    error_message = "System containers must never become Kubernetes nodes."
  }
  assert {
    condition     = proxmox_virtual_environment_container.this["cloudflared"].initialization[0].user_account[0].keys == tolist([var.ssh_public_key]) && proxmox_virtual_environment_container.this["cloudflared"].operating_system[0].type == "ubuntu"
    error_message = "Ubuntu system containers require OS initialization and the configured public key."
  }
}

run "http_template_requires_checksum" {
  command = plan

  variables {
    lxc_templates = {
      ubuntu = {
        url          = "http://example.invalid/ubuntu.tar.zst"
        file_name    = "ubuntu.tar.zst"
        datastore_id = "templates"
      }
    }
  }

  expect_failures = [var.lxc_templates]
}

run "system_container_requires_ssh_key" {
  command = plan

  variables {
    ssh_public_key = ""
    lxc_templates = {
      ubuntu = {
        url = "https://example.invalid/ubuntu.tar.xz", file_name = "ubuntu.tar.xz", datastore_id = "templates"
      }
    }
    containers = {
      cloudflared = {
        source = "template", image_key = "ubuntu", vm_id = 204,
        cores  = 1, memory_mb = 512, disk_gb = 8, ip_addr = "192.0.2.204/24"
      }
    }
  }

  expect_failures = [proxmox_virtual_environment_container.this]
}

run "system_container_missing_template" {
  command = plan

  variables {
    containers = {
      cloudflared = {
        source = "template", image_key = "ubuntu", vm_id = 204,
        cores  = 1, memory_mb = 512, disk_gb = 8, ip_addr = "192.0.2.204/24"
      }
    }
  }

  expect_failures = [proxmox_virtual_environment_container.this]
}
