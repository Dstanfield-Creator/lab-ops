# scripts

Operational helpers for the lab, kept here as the versions actually in use with credentials removed.

| Tool | What it does |
|---|---|
| [lab-power-scripts/](./lab-power-scripts/) | `lab-up` wakes the Proxmox host (Wake-on-LAN), waits for the API, starts VMs and containers in a safe order honouring `research` / `ds-lab` modes, then starts the Minecraft service. `lab-down` is the reverse with a force-stop fallback. The Proxmox API token is read from the environment, a 600-mode token file, or 1Password, never from the script. |
| [lab-ssh-check/](./lab-ssh-check/) | Sweeps every alias in `~/.ssh/config` in parallel and classifies each failure (DOWN / DNS / AUTH / HOSTKEY / HOSTKEY! / AGENT), skipping hosts known to be down. |

The firewall dead-man switch used when changing host networking remotely lives in the
[network](https://github.com/Dstanfield-Creator/network/tree/main/firewall/firewall-deadman-switch) repo.
