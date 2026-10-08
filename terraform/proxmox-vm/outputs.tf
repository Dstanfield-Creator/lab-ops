output "vm_id" {
  description = "Proxmox VM ID."
  value       = proxmox_virtual_environment_vm.this.vm_id
}

output "vm_name" {
  description = "VM name and guest hostname."
  value       = proxmox_virtual_environment_vm.this.name
}

output "node_name" {
  description = "Node the VM runs on."
  value       = proxmox_virtual_environment_vm.this.node_name
}

output "protection" {
  description = "Whether the Proxmox protection flag is set."
  value       = proxmox_virtual_environment_vm.this.protection
}

output "ipv4_addresses" {
  description = "IPv4 addresses reported by the QEMU guest agent, loopback excluded."
  value = distinct(flatten([
    for addrs in proxmox_virtual_environment_vm.this.ipv4_addresses :
    [for ip in addrs : ip if ip != "127.0.0.1"]
  ]))
}

output "primary_ipv4" {
  description = "First non-loopback IPv4 address, or null until the guest agent reports one."
  value = try(distinct(flatten([
    for addrs in proxmox_virtual_environment_vm.this.ipv4_addresses :
    [for ip in addrs : ip if ip != "127.0.0.1"]
  ]))[0], null)
}

output "mac_addresses" {
  description = "MAC addresses of the VM network devices."
  value       = proxmox_virtual_environment_vm.this.mac_addresses
}

output "cloud_image_file_id" {
  description = "Datastore ID of the downloaded Debian cloud image."
  value       = proxmox_virtual_environment_download_file.debian_cloud_image.id
}

output "user_data_file_id" {
  description = "Datastore ID of the cloud-init user-data snippet."
  value       = proxmox_virtual_environment_file.cloud_init_user_data.id
}
