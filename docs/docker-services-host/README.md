# Docker Services Host

> The lab's self-hosted services platform, migrated from a Raspberry Pi 5 to a Proxmox VM so it can be snapshotted, backed up and given real resources.

**Category:** Homelab · **Status:** Migration in progress (VM built Sep 2026, service stack being redeployed) · **Platform:** Debian VM 109 on Proxmox, Docker Engine 29

## History

| Generation | Platform | Notes |
|---|---|---|
| v1 `dockerpi` | Raspberry Pi 5, 8 GB, SD card, SSH on a non-standard port | Ran Grafana, n8n, Nginx Proxy Manager and a RustDesk relay. Cheap and quiet, but ARM-only images, SD-card wear and no snapshots |
| v2 `docker-host` | Proxmox VM 109: 4 vCPU, 8 GB RAM, 100 GB on LVM-thin | x86-64, lives on the same host as everything else, backed up by PBS, rebuilt from compose files |

The Pi was retired in September 2026. Its address is kept out of every script and SSH config so nothing can accidentally target the old box.

## Target service stack

| Service | Image | Purpose | Exposed via |
|---|---|---|---|
| Nginx Proxy Manager | `jc21/nginx-proxy-manager` | TLS termination and friendly hostnames for everything below | :80 / :443, admin :81 (LAN only) |
| n8n | `docker.n8n.io/n8nio/n8n` | Workflow automation: lab notifications, log enrichment, scheduled checks | NPM |
| Grafana | `grafana/grafana-oss` | Dashboards for [MyDashboard](https://github.com/Dstanfield-Creator/cyber-resources/tree/master/monitoring/mydashboard/) | NPM |
| RustDesk server | `rustdesk/rustdesk-server` (`hbbs` + `hbbr`) | Self-hosted remote desktop relay for family machines | :21115–21119 |
| Uptime Kuma *(planned)* | `louislam/uptime-kuma` | Up/down checks for lab services | NPM |

See [`docker-compose.example.yml`](./docker-compose.example.yml) and [`.env.example`](.env.example).

## Build

```bash
# VM: Debian 12 cloud image, qemu-guest-agent, static DHCP lease on the router
sudo apt-get install -y ca-certificates curl
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker "$USER"

# host firewall: SSH from the LAN, web ports from the LAN, RustDesk from the tailnet
sudo ufw allow from 192.0.2.0/24 to any port 22 proto tcp
sudo ufw allow from 192.0.2.0/24 to any port 80,443,81 proto tcp
sudo ufw allow in on tailscale0 to any port 21115:21119
# arm a rollback first — see tools/firewall-deadman-switch
sudo fw-deadman arm && sudo ufw --force enable

mkdir -p ~/stacks/lab && cd ~/stacks/lab
cp docker-compose.example.yml docker-compose.yml && cp .env.example .env   # edit .env
docker compose up -d
```

## Operations

- **Backups:** add the VM to the weekly PBS job once the stack is in place; keep compose files and `.env` in a private git repo. Named volumes hold application state, bind mounts hold NPM certificates.
- **Updates:** `docker compose pull && docker compose up -d` monthly; Watchtower deliberately not used so updates happen when someone is watching.
- **Monitoring:** container state scraped by cAdvisor for Grafana (planned, see MyDashboard).
- **Access:** SSH with keys only; `lab-ssh-check` confirms reachability after every `lab-up`.

## Lessons learned

- **SD cards are not storage.** The VM gets thin-provisioned NVMe, Proxmox snapshots and PBS backups, none of which a Pi on a microSD card can offer.
- **ARM is a tax.** Several images had no arm64 build or lagged weeks behind. x86-64 removed a whole class of "why is this version old" problems.
- **Don't let documentation outlive the hardware.** A wiki page still described the Pi's services months later. Retire the docs with the box.
- **Scope SSH and admin ports to the LAN.** The NPM admin UI and SSH are never reachable from the internet; remote access is over Tailscale.

## Skills demonstrated

Docker / Compose · reverse proxy and TLS · service migration planning · UFW hardening · Proxmox VM provisioning

## Related

- [Proxmox Lab Platform](../proxmox-lab-platform/) · [MyDashboard](https://github.com/Dstanfield-Creator/cyber-resources/tree/master/monitoring/mydashboard/) · [Tailscale Remote Access](https://github.com/Dstanfield-Creator/network/tree/main/remote-access/tailscale-remote-access/) · [Firewall Dead-Man Switch](https://github.com/Dstanfield-Creator/network/tree/main/firewall/firewall-deadman-switch/)

---

**Author:** Danny Stanfield · Perth, WA  
**License:** MIT
