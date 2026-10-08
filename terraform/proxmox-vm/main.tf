# Proxmox VE: Debian 12 cloud-image VM with cloud-init
#
# Authentication is read from the environment by the bpg/proxmox provider:
#   PROXMOX_VE_ENDPOINT   e.g. https://192.0.2.10:8006/
#   PROXMOX_VE_API_TOKEN  e.g. terraform@pve!tf=<token-secret>
# Never put these values in .tf or .tfvars files.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.60"
    }
  }
}

provider "proxmox" {
  # endpoint and api_token are intentionally omitted; see the header comment.
  insecure = var.proxmox_insecure

  # The Proxmox API cannot upload snippets, so the provider copies the
  # cloud-init user-data to the node over SSH. The SSH user is taken from
  # PROXMOX_VE_SSH_USERNAME and the key from the local ssh-agent.
  ssh {
    agent = true
  }
}

locals {
  # Rendered with yamlencode so multi-key lists and quoting are always valid.
  # The first line must be the literal "#cloud-config" marker.
  cloud_init_user_data = join("\n", [
    "#cloud-config",
    yamlencode({
      hostname         = var.vm_name
      manage_etc_hosts = true
      timezone         = var.timezone
      users = [
        {
          name                = var.cloud_init_username
          groups              = ["sudo"]
          shell               = "/bin/bash"
          sudo                = "ALL=(ALL) NOPASSWD:ALL"
          lock_passwd         = true
          ssh_authorized_keys = [for k in var.ssh_public_keys : trimspace(k)]
        }
      ]
      ssh_pwauth      = false
      package_update  = true
      package_upgrade = var.cloud_init_upgrade_packages
      packages        = ["qemu-guest-agent"]
      runcmd = [
        ["systemctl", "enable", "--now", "qemu-guest-agent"],
      ]
    }),
  ])
}

# Debian 12 "genericcloud" image. Proxmox only accepts .iso/.img names for
# the iso content type, so the qcow2 is stored with a .img extension; QEMU
# detects the real format from the file header.
resource "proxmox_virtual_environment_download_file" "debian_cloud_image" {
  content_type       = "iso"
  datastore_id       = var.image_datastore_id
  node_name          = var.node_name
  url                = var.cloud_image_url
  file_name          = var.cloud_image_file_name
  checksum           = var.cloud_image_checksum
  checksum_algorithm = var.cloud_image_checksum == null ? null : var.cloud_image_checksum_algorithm
  overwrite          = false
}

resource "proxmox_virtual_environment_file" "cloud_init_user_data" {
  content_type = "snippets"
  datastore_id = var.snippets_datastore_id
  node_name    = var.node_name

  source_raw {
    data      = local.cloud_init_user_data
    file_name = "${var.vm_name}-user-data.yaml"
  }
}

resource "proxmox_virtual_environment_vm" "this" {
  name        = var.vm_name
  description = var.vm_description
  tags        = var.vm_tags
  node_name   = var.node_name
  vm_id       = var.vm_id

  protection      = var.protection
  on_boot         = var.start_on_boot
  started         = true
  stop_on_destroy = true

  agent {
    enabled = true
    trim    = true
  }

  cpu {
    cores = var.cpu_cores
    type  = var.cpu_type
  }

  memory {
    dedicated = var.memory_mb
  }

  disk {
    datastore_id = var.vm_datastore_id
    file_id      = proxmox_virtual_environment_download_file.debian_cloud_image.id
    interface    = "virtio0"
    file_format  = "raw" # LVM-thin volumes are always raw
    size         = var.disk_size_gb
    iothread     = true
    discard      = "on"
  }

  network_device {
    bridge  = var.network_bridge
    model   = "virtio"
    vlan_id = var.vlan_id
  }

  operating_system {
    type = "l26"
  }

  # Debian cloud images log to the serial console.
  serial_device {}

  vga {
    type = "serial0"
  }

  initialization {
    datastore_id      = var.vm_datastore_id
    interface         = "ide2"
    user_data_file_id = proxmox_virtual_environment_file.cloud_init_user_data.id

    ip_config {
      ipv4 {
        address = var.ipv4_address
        gateway = var.ipv4_address == "dhcp" ? null : var.ipv4_gateway
      }
    }

    dynamic "dns" {
      for_each = length(var.dns_servers) > 0 ? [1] : []
      content {
        servers = var.dns_servers
      }
    }
  }

  lifecycle {
    precondition {
      condition     = var.ipv4_address == "dhcp" || var.ipv4_gateway != null
      error_message = "ipv4_gateway must be set when ipv4_address is a static CIDR."
    }
  }
}
