# proxmox

Notes on the hypervisor layer. There is no Proxmox config committed here -
the host is managed through its own web UI and API - but the conventions the
lab follows are written down so they survive a rebuild.

## The node

A single physical host runs Proxmox VE. It carries every VM in this lab:
`docker-host` for the Compose stacks, `paperclip` for assistant/agent
workloads, a Proxmox Backup Server (PBS) VM, and a throwaway attack box used
for practice. A single Linux bridge gives the guests access to the lab LAN;
documentation uses the RFC 5737 range `192.0.2.0/24` in place of the real one.

## API tokens: least privilege

Automation that talks to the Proxmox API uses a dedicated API token, not the
root account and not a password:

- Create a purpose-specific user (for example `automation@pve`) and issue it an
  API token; scripts authenticate with the token ID and secret.
- Grant only the roles that the task needs on only the paths it touches - for
  example `VM.PowerMgmt` and `VM.Audit` for a power-control script - rather
  than `Administrator` at `/`.
- Keep `Privilege Separation` enabled on the token so it cannot exceed the
  user's own grants, and store the secret in 1Password, never in git.

The token secret is shown once at creation; the lab scripts read it from the
environment, a token file, or 1Password at run time.

## Backups to PBS

The Proxmox Backup Server VM is the backup target for the node. A scheduled
backup job runs weekly, writing deduplicated, incremental snapshots of the VMs
to the PBS datastore. Restores are tested periodically rather than assumed;
a backup that has never been restored is a hypothesis, not a backup.

## Host power

Host power and the lab's start/stop ordering are handled by helper scripts
(see `../scripts/`), which use a least-privilege Proxmox API token as above.
The design notes and the firewall dead-man-switch pattern they rely on are
written up in the companion projects repository:
[the build write-ups in docs/](../docs/).
