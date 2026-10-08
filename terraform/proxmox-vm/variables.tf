# --- Provider ----------------------------------------------------------------

variable "proxmox_insecure" {
  description = "Skip TLS verification of the Proxmox API endpoint. Only for self-signed certificates on trusted networks."
  type        = bool
  default     = false
}

# --- Placement ---------------------------------------------------------------

variable "node_name" {
  description = "Proxmox node that will host the VM and store the image and snippet."
  type        = string
}

variable "vm_id" {
  description = "Numeric VM ID. Leave null to let Proxmox pick the next free ID."
  type        = number
  default     = null
}

variable "vm_name" {
  description = "VM name, also used as the guest hostname and the snippet file name."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{0,62}$", var.vm_name))
    error_message = "vm_name must be a lowercase DNS label (a-z, 0-9, hyphen)."
  }
}

variable "vm_description" {
  description = "Free-text description shown in the Proxmox UI."
  type        = string
  default     = "Debian 12 cloud image. Managed by Terraform."
}

variable "vm_tags" {
  description = "Proxmox tags applied to the VM."
  type        = list(string)
  default     = ["terraform", "debian12"]
}

variable "protection" {
  description = "Set the Proxmox protection flag. When true, the VM and its disks cannot be removed until the flag is cleared."
  type        = bool
  default     = false
}

variable "start_on_boot" {
  description = "Start the VM automatically when the node boots."
  type        = bool
  default     = true
}

# --- Compute -----------------------------------------------------------------

variable "cpu_cores" {
  description = "Number of vCPU cores."
  type        = number
  default     = 2
}

variable "cpu_type" {
  description = "QEMU CPU type. x86-64-v2-AES is the Proxmox 8 default and migrates safely; use host for maximum performance."
  type        = string
  default     = "x86-64-v2-AES"
}

variable "memory_mb" {
  description = "Dedicated memory in MiB."
  type        = number
  default     = 2048
}

# --- Storage -----------------------------------------------------------------

variable "vm_datastore_id" {
  description = "LVM-thin datastore for the VM disk and the cloud-init drive."
  type        = string
  default     = "local-lvm"
}

variable "disk_size_gb" {
  description = "Root disk size in GiB. The cloud image is resized up to this value on import."
  type        = number
  default     = 20
}

variable "image_datastore_id" {
  description = "Datastore that holds the downloaded cloud image. Must allow the iso content type."
  type        = string
  default     = "local"
}

variable "snippets_datastore_id" {
  description = "Datastore that holds the cloud-init user-data snippet. Must allow the snippets content type."
  type        = string
  default     = "local"
}

variable "cloud_image_url" {
  description = "URL of the Debian 12 generic cloud image (qcow2)."
  type        = string
  default     = "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2"
}

variable "cloud_image_file_name" {
  description = "File name to store the image under. Must end in .img or .iso for the iso content type."
  type        = string
  default     = "debian-12-genericcloud-amd64.img"

  validation {
    condition     = can(regex("\\.(img|iso)$", var.cloud_image_file_name))
    error_message = "cloud_image_file_name must end in .img or .iso."
  }
}

variable "cloud_image_checksum" {
  description = "Expected checksum of the image. Take it from SHA512SUMS next to the image. Null skips verification."
  type        = string
  default     = null
}

variable "cloud_image_checksum_algorithm" {
  description = "Algorithm for cloud_image_checksum."
  type        = string
  default     = "sha512"

  validation {
    condition     = contains(["md5", "sha1", "sha224", "sha256", "sha384", "sha512"], var.cloud_image_checksum_algorithm)
    error_message = "Use one of md5, sha1, sha224, sha256, sha384, sha512."
  }
}

# --- Network -----------------------------------------------------------------

variable "network_bridge" {
  description = "Linux bridge on the node to attach the VirtIO NIC to."
  type        = string
  default     = "vmbr0"
}

variable "vlan_id" {
  description = "Optional 802.1Q VLAN tag for the NIC."
  type        = number
  default     = null
}

variable "ipv4_address" {
  description = "Either \"dhcp\" or a static address in CIDR form, for example 192.0.2.50/24."
  type        = string
  default     = "dhcp"

  validation {
    condition     = var.ipv4_address == "dhcp" || can(cidrhost(var.ipv4_address, 0))
    error_message = "ipv4_address must be \"dhcp\" or an IPv4 CIDR such as 192.0.2.50/24."
  }
}

variable "ipv4_gateway" {
  description = "Default gateway. Required when ipv4_address is static, ignored for DHCP."
  type        = string
  default     = null
}

variable "dns_servers" {
  description = "DNS resolvers to push via cloud-init. Empty list uses the node defaults or DHCP."
  type        = list(string)
  default     = []
}

# --- Cloud-init --------------------------------------------------------------

variable "cloud_init_username" {
  description = "Login user created by cloud-init with passwordless sudo and the SSH keys below."
  type        = string
  default     = "admin"
}

variable "ssh_public_keys" {
  description = "SSH public keys authorised for cloud_init_username. Password authentication is disabled."
  type        = list(string)

  validation {
    condition     = length(var.ssh_public_keys) > 0
    error_message = "Provide at least one SSH public key; password login is disabled."
  }
}

variable "cloud_init_upgrade_packages" {
  description = "Run a full package upgrade on first boot."
  type        = bool
  default     = true
}

variable "timezone" {
  description = "IANA time zone name for the guest."
  type        = string
  default     = "Etc/UTC"
}
