# scripts

Operational helpers for the lab. The scripts themselves are kept with the
tooling they belong to; this directory is a pointer and a place for
lab-specific wrappers.

Typical helpers:

- **lab-up / lab-down** - start and stop the VMs in a safe order using a
  least-privilege Proxmox API token (read from the environment, a token file,
  or 1Password - never hardcoded).
- **lab-ssh-check** - sweep the lab for SSH reachability, skipping hosts that
  are known to be down.

The reasoning behind these tools, and the firewall dead-man-switch pattern used
when changing host networking remotely, is written up in the companion
projects repository:
[Dstanfield-Creator/projects](https://github.com/Dstanfield-Creator/projects).
