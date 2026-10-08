# Proxmox Lab Platform

> A single-node Proxmox VE host that runs a cyber range, an AI-agent platform, a Docker services VM, an attack box and its own backup server, and powers itself off when nobody is using it.

**Category:** Homelab · **Status:** Active · **Hypervisor:** Proxmox VE 9.x (Linux 7.0 kernel)

This is the hub project. Most other homelab entries in this repo are workloads on this host.

## Hardware

| | |
|---|---|
| CPU | 16 threads |
| RAM | 96 GB |
| Boot / `local` | NVMe, ~96 GB `dir` storage for ISOs, templates and vzdump |
| `local-lvm` | ~816 GB LVM-thin pool for VM disks |
| Second NVMe | dedicated volume group for the Ludus range VMs |
| Network | single onboard NIC on the lab LAN, Wake-on-LAN enabled |

## Network

```mermaid
flowchart LR
  LAN["Home LAN<br/>router / UniFi"] --> VMBR0["vmbr0 - lab LAN 192.0.2.0/24<br/>pve, docker-host, paperclip,<br/>pbs, hackerv1, mcserver"]
  VMBR0 -.->|isolated| RANGE["vmbr1000-1002<br/>Ludus range bridges"]
  RANGE --> DSR["DS-router<br/>NATs the range out"]
```

- `vmbr0` is a plain (non-VLAN-aware) bridge on the lab LAN. The UniFi router upstream does DHCP and routing.
- `vmbr1000–1002` are created by [Ludus](https://github.com/Dstanfield-Creator/cyber-resources/tree/master/labs/ludus-cyber-range/). Range VMs sit behind the range's own Debian router VM, so a compromised Windows box in the range cannot see the real LAN.
- Remote access is over [Tailscale](https://github.com/Dstanfield-Creator/network/tree/main/remote-access/tailscale-remote-access/), not port-forwards.

> Addresses in this repo are RFC 5737 documentation examples. The real lab uses a private range.

## Guest inventory

| VMID | Name | Role | Notes |
|---:|---|---|---|
| 100–104 | `*-template` | Ludus golden images | Debian 12, Debian 11, Win 11 22H2 Enterprise, Server 2022, Kali |
| 105 | `DS-router-debian11-x64` | Range router / NAT | Auto-built by Ludus |
| 106 | `DS-ad-dc-win2022-server-x64` | Domain controller | Ludus range, 8 GB |
| 107 | `DS-ad-win11-22h2-enterprise-x64-1` | Domain-joined workstation | Ludus range |
| 108 | `DS-kali` | In-range attacker | Ludus range |
| 109 | `docker-host` | [Docker services](../docker-services-host/) | 4 vCPU / 8 GB / 100 GB |
| 110 | `hackerv1` | Attack / research box | On the tailnet |
| 111 | `omarchy-test` | Throwaway desktop test | **Standalone** — never touched by lab scripts |
| 210 | `paperclip` | [AI agent platform](https://github.com/Dstanfield-Creator/ai-automation/tree/main/paperclip-ai-agents/) | `protection=1`, backed up weekly |
| 211 | `pbs` | [Proxmox Backup Server](../proxmox-backup-server/) | `protection=1`, 250 GB datastore disk |

No LXC containers at present; everything that needs isolation is a VM.

## Operating modes

The lab is run in one of two shapes, selected by [`lab-up --mode`](../../scripts/lab-power-scripts/):

| Mode | What is on | Use |
|---|---|---|
| `research` | 109, 110, 210, 211 | Day-to-day: Docker services, attack box, agents, backups |
| `ds-lab` (default) | everything above **plus** 105–108 | Active Directory attack / detection work in the Ludus range |

## Power management

The host is **off** when the lab is idle. `lab-up` sends Wake-on-LAN, waits for ping and then for the API, and starts guests through the REST API with a least-privilege token. `lab-down` ACPI-shuts every guest, force-stops stragglers after two minutes, and powers the node off. Details: [Lab Power Scripts](../../scripts/lab-power-scripts/).

## Backups

Weekly vzdump (Sunday 02:00) of the range VMs and the Paperclip VM to the on-host [Proxmox Backup Server](../proxmox-backup-server/) with a 4-weekly / 3-monthly prune policy. The PBS datastore disk itself is excluded from vzdump.

## Access & secrets

- Admin SSH to the node uses a dedicated non-root user with sudo, keys served by the 1Password SSH agent.
- Automation uses **API tokens**, never passwords: one token for the lab scripts, one for the Paperclip agents, each with its own role. See [Paperclip AI Agents](https://github.com/Dstanfield-Creator/ai-automation/tree/main/paperclip-ai-agents/) for the role design.
- Secrets live in 1Password or in `~/.config/lab/` (700/600), never in scripts or git.

## Lessons learned

- **`local` fills up silently.** A weekly vzdump job to the 96 GB root disk failed for a month with `write error - Broken pipe` because the disk was full. That was the trigger to build PBS and move backups off `local`. Check `pvesm status` before any ISO download or backup to `local`.
- **Documentation drifts; the host does not lie.** An earlier wiki page described bridges, subnets and disk sizes that no longer existed. `ip -br link`, `pvesm status` and `qm list` are the source of truth, which is why the inventory above is read live, not from a diagram.
- **Protect what you cannot afford to lose.** `protection=1` on the PBS and Paperclip VMs stops an over-privileged automation token, or a tired human, from deleting them.
- **Scope every token.** Tokens are capped by their owning user's privileges, so an ACL granted only to the token does nothing. Grant the role to the user and the token.

## Skills demonstrated

Proxmox VE administration · LVM-thin storage · Linux bridging · API token / RBAC design · Wake-on-LAN and REST automation · backup design · operational documentation

## Related

- [Ludus Cyber Range](https://github.com/Dstanfield-Creator/cyber-resources/tree/master/labs/ludus-cyber-range/) · [Proxmox Backup Server](../proxmox-backup-server/) · [Docker Services Host](../docker-services-host/) · [Paperclip AI Agents](https://github.com/Dstanfield-Creator/ai-automation/tree/main/paperclip-ai-agents/) · [Tailscale Remote Access](https://github.com/Dstanfield-Creator/network/tree/main/remote-access/tailscale-remote-access/)
- [Lab Power Scripts](../../scripts/lab-power-scripts/) · [lab-ssh-check](../../scripts/lab-ssh-check/)

---

**Author:** Danny Stanfield · Perth, WA  
**License:** MIT
