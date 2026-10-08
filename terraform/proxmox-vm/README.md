# Terraform: Proxmox VE Debian 12 VM

> Terraform configuration for the bpg/proxmox provider that downloads a Debian 12 cloud image, uploads a cloud-init snippet and creates a VirtIO VM on LVM-thin with API-token authentication from environment variables.

**Status:** Active · **Updated:** 2026-10-08

## What it creates

| Resource | Type | Purpose |
|---|---|---|
| `debian_cloud_image` | `proxmox_virtual_environment_download_file` | Pulls `debian-12-genericcloud-amd64.qcow2` onto the node, stored as `.img` on the `iso` content type |
| `cloud_init_user_data` | `proxmox_virtual_environment_file` | Renders a `#cloud-config` snippet (user, SSH keys, qemu-guest-agent) and uploads it to the snippets datastore |
| `this` | `proxmox_virtual_environment_vm` | VM with VirtIO disk on LVM-thin, VirtIO NIC on a bridge, serial console, guest agent, cloud-init drive and the `protection` flag |

The VM boots from the imported image, cloud-init creates the login user, disables password authentication, installs `qemu-guest-agent` and reports its IP back to Terraform.

## Prerequisites

### Terraform and provider

- Terraform 1.5 or later.
- `bpg/proxmox` provider `~> 0.60` (resolved during `terraform init`).
- Proxmox VE 8.x. The `download_file` resource needs the `download-url` API, available since PVE 7.4.

### API token and privileges

Create a dedicated user, role and token on the Proxmox host. The token secret is shown once; store it in a password manager, not in this repository.

```bash
pveum role add Terraform -privs "Datastore.Allocate Datastore.AllocateSpace Datastore.AllocateTemplate Datastore.Audit Pool.Allocate Sys.Audit Sys.Console Sys.Modify Sys.AccessNetwork SDN.Use VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Migrate VM.Monitor VM.PowerMgmt"
pveum user add terraform@pve
pveum aclmod / -user terraform@pve -role Terraform
pveum user token add terraform@pve tf -privsep 0
```

Notes:

- `Sys.AccessNetwork` exists from PVE 8.1 and is required for the image download. Drop it from the list on older releases.
- `-privsep 0` makes the token inherit the user's permissions. With `-privsep 1` you must grant the ACL to the token itself.

### Snippets content type

Proxmox does not enable `snippets` on any datastore by default. Enable it on the datastore named in `snippets_datastore_id` (keep the existing content types):

```bash
pvesm set local --content backup,iso,vztmpl,snippets
grep -A3 '^dir: local$' /etc/pve/storage.cfg
```

In the GUI: Datacenter > Storage > local > Edit > Content > tick Snippets.

### SSH access for the snippet upload

The Proxmox API has no upload endpoint for snippets, so the provider copies the file over SSH. Make sure:

- Your workstation can `ssh` to the node as `PROXMOX_VE_SSH_USERNAME` using a key in the running `ssh-agent`.
- The user can write to the snippets directory (`/var/lib/vz/snippets` for `local`). `root` works out of the box; for a restricted user, add the sudo rules documented in the provider's SSH connection guide.

## Usage

```bash
export PROXMOX_VE_ENDPOINT="https://192.0.2.10:8006/"
export PROXMOX_VE_API_TOKEN="terraform@pve!tf=<token-secret>"
export PROXMOX_VE_SSH_USERNAME="root"

cp terraform.tfvars.example terraform.tfvars   # edit node, name, keys, network
terraform init
terraform plan
terraform apply

ssh admin@"$(terraform output -raw primary_ipv4)"
```

If the node uses a self-signed certificate, either trust the CA on your workstation or set `proxmox_insecure = true` in `terraform.tfvars`.

### DHCP or static addressing

| Mode | Settings |
|---|---|
| DHCP (default) | `ipv4_address = "dhcp"` |
| Static | `ipv4_address = "192.0.2.50/24"`, `ipv4_gateway = "192.0.2.1"`, optional `dns_servers = ["192.0.2.1"]` |

A precondition fails the plan if a static address is given without a gateway.

### Protection flag

`protection = true` sets the Proxmox protection flag. `terraform destroy` (and the GUI remove button) will then refuse to delete the VM or its disks until you set it back to `false` and apply again. Use it for anything you would be unhappy to recreate.

## Variables

| Name | Default | Description |
|---|---|---|
| `node_name` | required | Node that hosts the VM, image and snippet |
| `vm_name` | required | VM name and guest hostname (lowercase DNS label) |
| `ssh_public_keys` | required | List of SSH public keys for the cloud-init user |
| `vm_id` | `null` | Fixed VM ID, or auto-assign |
| `protection` | `false` | Proxmox protection flag |
| `start_on_boot` | `true` | Autostart with the node |
| `cpu_cores` / `cpu_type` | `2` / `x86-64-v2-AES` | vCPU count and QEMU CPU model |
| `memory_mb` | `2048` | Dedicated memory in MiB |
| `vm_datastore_id` | `local-lvm` | LVM-thin datastore for the disk and cloud-init drive |
| `disk_size_gb` | `20` | Root disk size; the image is grown to this on import |
| `image_datastore_id` | `local` | Datastore with the `iso` content type for the image |
| `snippets_datastore_id` | `local` | Datastore with the `snippets` content type |
| `cloud_image_url` | Debian bookworm latest | qcow2 image URL |
| `cloud_image_file_name` | `debian-12-genericcloud-amd64.img` | Stored file name (`.img` or `.iso`) |
| `cloud_image_checksum` | `null` | SHA-512 from `SHA512SUMS`; null skips verification |
| `network_bridge` / `vlan_id` | `vmbr0` / `null` | Bridge and optional VLAN tag |
| `ipv4_address` / `ipv4_gateway` | `dhcp` / `null` | DHCP or static CIDR plus gateway |
| `dns_servers` | `[]` | Resolvers pushed through cloud-init |
| `cloud_init_username` | `admin` | Login user with passwordless sudo |
| `cloud_init_upgrade_packages` | `true` | Full `apt upgrade` on first boot |
| `timezone` | `Etc/UTC` | Guest time zone |
| `proxmox_insecure` | `false` | Skip TLS verification of the API endpoint |

## Outputs

| Name | Description |
|---|---|
| `vm_id`, `vm_name`, `node_name` | Identity of the VM |
| `protection` | Current protection flag |
| `ipv4_addresses`, `primary_ipv4` | Addresses reported by the guest agent |
| `mac_addresses` | NIC MAC addresses |
| `cloud_image_file_id`, `user_data_file_id` | Datastore IDs of the image and snippet |

## Notes

- When a custom user-data snippet is attached, Proxmox ignores its own `ciuser`, `cipassword` and `sshkeys` fields. Everything about the login user comes from the snippet; network and meta-data are still generated by Proxmox from `ip_config` and `dns`.
- `terraform apply` waits for the guest agent to come up before reporting addresses. First boot includes `apt upgrade`, so allow a few minutes; the agent timeout defaults to 15 minutes.
- To pin the image, copy the matching line from `SHA512SUMS` into `cloud_image_checksum`. The `latest` directory changes with each Debian point release, which will trigger a re-download only if the checksum changes.
- Changing `cloud_init_*` variables replaces the snippet, but cloud-init only runs on first boot. Recreate the VM (`terraform taint`, or `-replace`) to apply new user-data.

## Teardown

```bash
terraform destroy
```

Fails on purpose while `protection = true`. The downloaded image is also removed; set `overwrite = false` as shipped to avoid re-downloading when the file already exists.

---

**Author:** Danny Stanfield · Perth, WA  
**License:** MIT
