# lab-ops

> Infrastructure-as-code for a single-node Proxmox homelab: host baseline in Ansible, services in Docker Compose, configuration in git.

**Status:** Active · **Updated:** 2026-10-08

## Overview

This repository expresses a single-node [Proxmox VE](https://www.proxmox.com/) homelab
as code. One physical host runs the hypervisor; a handful of VMs run Docker and other
workloads on top of it. The goal is that the interesting state of the lab lives in
version control rather than in a bunch of hand-edited files on a box that only I
remember the shape of.

The approach is GitOps-lite:

- **Host baseline** is an Ansible role (`common`) that every VM gets: an admin user,
  SSH hardening, a host firewall, and automatic security updates.
- **Services** are Docker Compose stacks with pinned image tags and named volumes, so a
  rebuild is reproducible rather than archaeological.
- **Secrets stay out of git.** Only `.example` files are committed; real values come from
  a local `.env`, Ansible Vault, or 1Password.
- **Dependencies are watched** by Renovate, which opens pull requests when a pinned image
  or action has an update.

The narrative write-ups - why things are built the way they are, what broke, and what I
learned - live in [`docs/`](./docs/). The scripts actually in use live in
[`scripts/`](./scripts/), and the Proxmox VM Terraform in [`terraform/`](./terraform/).
Monitoring stacks live in [cyber-resources/monitoring](https://github.com/Dstanfield-Creator/cyber-resources/tree/master/monitoring);
network builds and firewall tooling in [network](https://github.com/Dstanfield-Creator/network).

## Architecture

```mermaid
flowchart TB
    subgraph host[Proxmox host]
        pve[Proxmox VE]
    end

    subgraph lan[Lab LAN bridge]
        docker[VM: docker-host]
        paperclip[VM: paperclip]
        pbs[VM: backup server]
        attack[VM: attack box]
    end

    ts[Tailscale mesh]

    pve --> docker
    pve --> paperclip
    pve --> pbs
    pve --> attack

    docker --- lan
    paperclip --- lan
    pbs --- lan
    attack --- lan

    ts -.remote access.-> docker
    ts -.remote access.-> paperclip
    pbs -.backups.-> pve
```

## Repository Layout

```text
lab-ops/
├── ansible/                 # Host baseline as code
│   ├── ansible.cfg          # Inventory path, SSH defaults
│   ├── inventory.example.ini # Example inventory (copy to inventory.ini)
│   ├── group_vars/          # Example variable overrides
│   ├── playbooks/           # Entry-point playbooks (baseline.yml)
│   └── roles/common/        # Admin user, SSH hardening, UFW, updates
├── compose/
│   └── services/            # Reverse proxy, n8n, status page (monitoring stacks: see monitoring repo)
├── terraform/
│   └── proxmox-vm/          # Debian 12 cloud-image VM via bpg/proxmox: image, cloud-init snippet, LVM-thin disk
├── scripts/
│   ├── lab-power-scripts/   # lab-up / lab-down: Wake-on-LAN + Proxmox API orchestration
│   └── lab-ssh-check/       # Parallel SSH reachability + key-auth checker
├── docs/                    # Build write-ups
│   ├── proxmox-lab-platform/    # The single-node PVE host everything runs on
│   ├── proxmox-backup-server/   # Dedicated PBS VM, token ACLs, prune policy
│   ├── docker-services-host/    # Services VM migrated from a Raspberry Pi 5 (+ compose reference)
│   ├── minecraft-server/        # systemd-managed game server, Tailscale-only
│   └── cloud-init-for-proxmox-and-cloud-vms.md
├── proxmox/                 # Hypervisor notes: API tokens, PBS backups
├── renovate.json            # Dependency update automation config
├── CONTRIBUTING.md          # Sanitisation rules
├── LICENSE
└── README.md
```

## Contents

### Build write-ups (`docs/`)

| Project | Summary | Status |
|---|---|---|
| [Proxmox Lab Platform](./docs/proxmox-lab-platform/) | 16-thread / 96 GB PVE 9 host: storage layout, bridges, guest inventory, research vs ds-lab modes, power management, backups | Active |
| [Proxmox Backup Server](./docs/proxmox-backup-server/) | PBS 4 on its own datastore disk after a month of silent vzdump failures; token ACL gotchas documented | Active |
| [Docker Services Host](./docs/docker-services-host/) | NPM, n8n, Grafana, RustDesk stack moving from a Pi 5 to a PVE VM; compose reference included | In progress |
| [Minecraft Server](./docs/minecraft-server/) | Bare-metal game server under systemd, started/stopped with the lab, Tailscale access | Active |
| [Cloud-init for Proxmox and Cloud VMs](./docs/cloud-init-for-proxmox-and-cloud-vms.md) | User-data guide: users and keys, sshd hardening, packages, UFW baseline, attaching on Proxmox and AWS | Active |

### Scripts (`scripts/`)

| Tool | Summary | Status |
|---|---|---|
| [Lab Power Scripts](./scripts/lab-power-scripts/) | `lab-up` / `lab-down`: Wake-on-LAN, API polling, mode-aware VM start, graceful shutdown with force-stop fallback, logging; token from env, file or 1Password | Active |
| [lab-ssh-check](./scripts/lab-ssh-check/) | Checks every alias in `~/.ssh/config` in parallel and classifies DOWN / DNS / AUTH / HOSTKEY / HOSTKEY! | Active |

### Provisioning (`terraform/`)

| Module | Summary |
|---|---|
| [proxmox-vm](./terraform/proxmox-vm/) | Debian 12 cloud-image VM on Proxmox VE with the bpg/proxmox provider: image download, cloud-init snippet, LVM-thin disk, API token from environment variables |

## Tech Stack

| Layer            | Tool                     | Role in the lab                              |
| ---------------- | ------------------------ | -------------------------------------------- |
| Hypervisor       | Proxmox VE               | Runs the VMs on the single physical host     |
| Guest OS         | Debian                   | Base image for every VM                      |
| Config mgmt      | Ansible                  | Applies the `common` host baseline           |
| Services         | Docker Compose           | Runs containerised workloads on docker-host  |
| Observability    | Prometheus / Grafana     | Stacks live in [cyber-resources/monitoring](https://github.com/Dstanfield-Creator/cyber-resources/tree/master/monitoring) |
| Remote access    | Tailscale                | Mesh VPN; no ports exposed to the internet   |
| Dependency bot   | Renovate                 | Opens PRs for image and action updates       |
| CI               | GitHub Actions           | Lint and validate on push (added separately) |

## Usage

Apply the host baseline to all inventory hosts:

```bash
cd ansible
cp inventory.example.ini inventory.ini   # then edit for your hosts
cp group_vars/all.example.yml group_vars/all.yml
ansible-playbook playbooks/baseline.yml
```

Run against a single host, or check what would change first:

```bash
ansible-playbook playbooks/baseline.yml --limit docker-host --check --diff
```

Bring up the services Compose stack:

```bash
cd compose/services
cp .env.example .env                      # then fill in local values
docker compose pull
docker compose up -d
docker compose ps
```

## Secrets

Nothing secret is committed to this repository.

- Every stack ships a `.env.example`; the real `.env` is git-ignored and lives only on
  the host.
- Ansible variables that carry secrets are kept in Ansible Vault, or pulled from
  1Password at run time, never in plain `group_vars`.
- Only RFC 5737 documentation addresses (`192.0.2.0/24`), `example.com`, and
  `example.ts.net` appear in committed files. Substitute your own before use.

---

**Author:** Danny Stanfield · Perth, WA

**License:** MIT
