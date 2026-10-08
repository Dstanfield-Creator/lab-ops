# Lab Power Scripts — `lab-up` / `lab-down`

> One command to wake the whole homelab from cold, one command to shut it all down cleanly.

**Category:** Tools · **Status:** Active (in daily use) · **Language:** Bash + a little inline Python · **Target:** Proxmox VE 8/9

## Why

The Proxmox host is powered off when the lab is not in use (power bill, noise, and it is a single node with no HA to protect). Bringing it back by hand meant: send a magic packet, wait, log into the web UI, start a dozen guests in the right order, then SSH to a separate box to start the Minecraft service. `lab-up` does all of that in about 90 seconds and logs every run. `lab-down` reverses it with a graceful ACPI shutdown and a force-stop fallback so the host never hangs waiting on a stuck guest.

## What they do

| Step | `lab-up` | `lab-down` |
|---|---|---|
| 1 | Send Wake-on-LAN to the host's MAC (pure-Python magic packet, no `wakeonlan` dependency) | Confirm the host answers ping, otherwise exit |
| 2 | Poll ping until the host is up (`BOOT_TIMEOUT`, default 180 s) | Stop the Minecraft systemd service over SSH |
| 3 | Poll the API on :8006 until it answers (`API_TIMEOUT`) | ACPI-shutdown every running QEMU VM (skipping `STANDALONE_VMS`) |
| 4 | Start every non-template QEMU VM, honouring **mode** and `STANDALONE_VMS` | ACPI-shutdown every running LXC container |
| 5 | Start every LXC container | Wait up to `SHUTDOWN_TIMEOUT` (120 s), then **force-stop** stragglers |
| 6 | Start the Minecraft service on its host over SSH and confirm it is active | Send `shutdown` to the node via the API |
| 7 | Print a summary with the UI URL | Print a summary |

Both scripts `tee` everything to `~/.lab/lab-YYYYMMDD.log`; `lab-up` prunes logs older than 30 days.

### Modes

```
lab-up                    # ds-lab (default): everything, including the AD range
lab-up --mode research    # skip VMs 105-108 (the Ludus AD range) — just infra + attack box
```

Two arrays at the top of the script control what is touched:

- `DS_LAB_VMS=(105 106 107 108)` — the Active Directory range, left off in research mode.
- `STANDALONE_VMS=(111)` — one-off test VMs the scripts never start or stop.

## Credentials

The scripts talk to the Proxmox REST API with a dedicated **API token** (`lab-agent@pve!lab-scripts`) that has only the privileges needed to query and start/stop guests and shut the node down. The token is **not** in the script. It is resolved in this order:

1. `$PROXMOX_TOKEN` in the environment
2. `~/.config/lab/proxmox.token` (mode 600), the fast path for unattended runs
3. 1Password CLI (`op item get … --fields "API Token Header"`), with a 20 s timeout because the desktop app may ask for approval

If none is found the script exits before doing anything. See [`lab.env.example`](./lab.env.example).

## Install

```bash
install -m 755 lab-up lab-down ~/bin/
# edit the Config block at the top of each script: host IP, node name, MAC, SSH alias
mkdir -p ~/.config/lab && chmod 700 ~/.config/lab
# then store the token in 1Password, or:
printf 'PVEAPIToken=lab-agent@pve!lab-scripts=<secret>\n' > ~/.config/lab/proxmox.token && chmod 600 ~/.config/lab/proxmox.token
```

Create the token on the node with least privilege:

```bash
pveum user add lab-agent@pve
pveum role add LabScripts -privs "VM.Audit VM.PowerMgmt Sys.Audit Sys.PowerMgmt"
pveum acl modify / -user lab-agent@pve -role LabScripts
pveum user token add lab-agent@pve lab-scripts --privsep 0
```

## Example run

```
=== lab-up started 2026-10-05 09:58:17 | mode=ds-lab ===
Sending Wake-on-LAN to Proxmox (00:11:22:33:44:55)...
  WoL sent.
Waiting for Proxmox (192.0.2.10) to come online (up to 180s)...
  Proxmox is pingable.
Waiting for Proxmox API (port 8006)...
  Proxmox API is ready.
Starting QEMU VMs (mode=ds-lab)...
  VM 105 (DS-router-debian11-x64): already running
  VM 106 (DS-ad-dc-win2022-server-x64): already running
  VM 107 (DS-ad-win11-22h2-enterprise-x64-1): starting...
  VM 108 (DS-kali): already running
  VM 109 (docker-host): already running
  VM 110 (hackerv1): already running
  VM 111 (omarchy-test): skipped (standalone)
  VM 210 (paperclip): already running
  VM 211 (pbs): already running
Starting LXC containers...
  No LXC containers.
Checking mcserver (mcserver)...
  mcserver: Minecraft service active.

Lab is up  (mode=ds-lab).
=== lab-up finished 2026-10-05 09:59:47 ===
```

## Design notes

- **API over SSH.** Everything on the node goes through the REST API with a scoped token, so no root SSH key to the hypervisor is needed on the workstation.
- **Idempotent.** Already-running guests are reported, not restarted. Running `lab-up` twice is harmless.
- **Graceful first, forceful second.** `lab-down` gives guests two minutes to shut down on their own (Windows AD DCs need it) before `stop`.
- **Everything is logged.** The log is what showed the Minecraft host was unreachable one morning before anyone noticed in game.

## Related

- [Proxmox Lab Platform](../../docs/proxmox-lab-platform/) — the environment these scripts manage
- [lab-ssh-check](../lab-ssh-check/) — the reachability check that runs after `lab-up`
- [Minecraft Server](../../docs/minecraft-server/) — the service started in step 6

---

**Author:** Danny Stanfield · Perth, WA  
**License:** MIT
