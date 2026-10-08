# Cloud-init for Proxmox and Cloud VMs

> How to write cloud-init user-data for Debian and Ubuntu VMs (users, SSH keys, hardening, packages, UFW) and how to attach it on Proxmox VE and AWS.

**Status:** Active · **Updated:** 2026-10-08

## Overview

Cloud-init runs on the first boot of a cloud image and applies configuration from three inputs: user-data (what you write), meta-data (instance ID, hostname) and network-config (both supplied by the platform). Debian `genericcloud` and Ubuntu `cloudimg` images ship with cloud-init; a VM installed from a normal ISO does not. User-data must begin with the literal line `#cloud-config`; the rest is YAML.

## Module cheat sheet

| Key | Purpose | Notes |
|---|---|---|
| `users` | Create accounts with groups, shell, sudo rule and authorized keys | `lock_passwd: true` makes the account key-only. Listing `users` replaces the image default user unless `- default` is the first entry |
| `ssh_pwauth` | Password authentication in sshd | Set `false`; cloud-init writes its own sshd drop-in |
| `packages` | Install with apt | Pair with `package_update: true` |
| `write_files` | Create files with owner, mode and content | Runs before `packages` and `runcmd` |
| `runcmd` | Shell commands run once, late on first boot | Use for `systemctl`, `ufw`, anything stateful |
| `timezone` | Set `/etc/localtime` | IANA name such as `Etc/UTC` or `Australia/Perth` |
| `final_message` | Printed to the console when cloud-init finishes | Visible on the serial console or `qm terminal` |

## Full example

```yaml
#cloud-config
hostname: web01
fqdn: web01.example.com
manage_etc_hosts: true
timezone: Etc/UTC

users:
  - name: admin
    groups: [sudo]
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: true
    ssh_authorized_keys:
      - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExampleKeyReplaceMe admin@example.com

ssh_pwauth: false
disable_root: true

package_update: true
package_upgrade: true
packages:
  - qemu-guest-agent
  - ufw
  - unattended-upgrades

write_files:
  - path: /etc/ssh/sshd_config.d/10-hardening.conf
    owner: root:root
    permissions: "0644"
    content: |
      PasswordAuthentication no
      KbdInteractiveAuthentication no
      PermitRootLogin no
      PubkeyAuthentication yes
      X11Forwarding no
      MaxAuthTries 3

runcmd:
  - systemctl enable --now qemu-guest-agent
  - ufw default deny incoming
  - ufw default allow outgoing
  - ufw allow from 192.0.2.0/24 to any port 22 proto tcp
  - ufw --force enable
  - systemctl restart ssh

final_message: "cloud-init finished after $UPTIME seconds"
```

## Notes on the example

- sshd reads `/etc/ssh/sshd_config.d/*.conf` in name order and the first value for a keyword wins, so `10-hardening.conf` takes precedence over the `50-cloud-init.conf` that cloud-init writes. `systemctl restart ssh` applies it; on Ubuntu 22.10 and later the service is socket-activated but the same command works.
- `qemu-guest-agent` gives Proxmox IP reporting, clean shutdown and filesystem freeze for snapshots. On AWS the package installs and the service fails to find a VirtIO channel; drop it from the AWS variant.
- UFW order matters: set both defaults, add allows, then `--force enable` because `ufw enable` prompts. Replace `192.0.2.0/24` with your management network, or remove the SSH rule entirely on AWS and use Session Manager.
- Installing `unattended-upgrades` on Debian enables the daily run through `/etc/apt/apt.conf.d/20auto-upgrades`; Ubuntu cloud images ship it already. Confirm with `apt-config dump APT::Periodic`.
- Everything here runs once, keyed on the instance ID. To rerun after editing: `sudo cloud-init clean --logs && sudo reboot`.

## Attaching on Proxmox VE

Proxmox generates its own user-data from `--ciuser`, `--cipassword` and `--sshkeys`. A custom file replaces that generated user-data entirely while network and meta-data are still produced from `--ipconfig0` and friends.

1. Enable the `snippets` content type on a directory datastore (keep its existing types): `pvesm set local --content backup,iso,vztmpl,snippets`. For `local` the files live in `/var/lib/vz/snippets/`.
2. Copy the file to the node: `scp user-data.yaml root@192.0.2.10:/var/lib/vz/snippets/web01-user-data.yaml`
3. Attach it and regenerate the cloud-init drive:

```bash
qm set 9001 --ide2 local-lvm:cloudinit                               # cloud-init drive, once
qm set 9001 --cicustom "user=local:snippets/web01-user-data.yaml"
qm set 9001 --ipconfig0 ip=dhcp                                      # or ip=192.0.2.50/24,gw=192.0.2.1
qm cloudinit update 9001                                             # rebuild the ISO on the drive
qm cloudinit dump 9001 user                                          # show what the guest will receive
qm start 9001
```

`qm cloudinit dump <vmid> user` prints the generated user-data when no custom file is attached, or the contents of your snippet when one is. Proxmox needs `VM.Config.Cloudinit` on the VM and `Datastore.AllocateSpace` on the snippets datastore for these calls. The Terraform version of this flow is in `terraform/proxmox-vm/`.

## Attaching on AWS

User-data is a launch parameter. Pass the file at creation time:

```bash
aws ec2 run-instances --image-id ami-0123456789abcdef0 --instance-type t3.micro \
  --subnet-id subnet-0123456789abcdef0 --security-group-ids sg-0123456789abcdef0 \
  --user-data file://user-data.yaml
```

In the console it is Launch instance > Advanced details > User data. To change it later, stop the instance, run `aws ec2 modify-instance-attribute --instance-id i-0123456789abcdef0 --attribute userData --value file://user-data.yaml`, then clear cloud-init state on the box or the new file will be ignored because the instance ID has not changed. User-data is readable by any process on the instance through IMDS, so never put secrets in it; fetch them from Secrets Manager or SSM Parameter Store at runtime instead.

## Validating

```bash
cloud-init schema --config-file user-data.yaml   # lint locally (cloud-init 22.2 or later)
cloud-init status --wait --long                  # on the VM: blocks until the first boot finishes
sudo cloud-init query userdata                   # user-data exactly as the VM received it
sudo tail -n 50 /var/log/cloud-init-output.log   # stdout/stderr of packages and runcmd
```

A VM that boots but has no user, no agent or no firewall almost always has a YAML indentation error, a missing `#cloud-config` first line, or a snippet path that does not match the datastore ID.

---

**Author:** Danny Stanfield · Perth, WA  
**License:** MIT
