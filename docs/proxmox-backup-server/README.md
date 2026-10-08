# Proxmox Backup Server

> Dedicated PBS 4 VM with its own datastore disk, replacing vzdump-to-root-disk after a month of silently failing backups.

**Category:** Homelab · **Status:** Active (weekly job healthy) · **Built:** September 2026 · **Software:** Proxmox Backup Server 4

## Background

The original backup job wrote weekly vzdump archives to the hypervisor's `local` storage, a 96 GB root disk. Nobody noticed when the dumps filled the disk; the job just started failing every Sunday with:

```
ERROR: Backup of VM 106 failed - write error - Broken pipe
```

for over a month. A full root disk also blocked ISO downloads and template builds. The fix was to stop using the root disk for backups at all.

## Design

| | |
|---|---|
| VM | 211 `pbs`, 4 GB RAM, 32 GB OS disk, `protection=1` |
| Datastore | `backup`, on a separate **250 GB** virtual disk, **excluded from vzdump** (`backup=0`) so the backup server does not back up its own backups |
| Clients | the Proxmox node, via a `pbs` storage entry named `pbs-backup` |
| Schedule | Sunday 02:00, VMs 105–108 (range) and 210 (Paperclip) |
| Retention | prune: keep 4 weekly + 3 monthly; GC weekly |
| Auth | PVE → PBS with an API token (`pve-backup@pbs!pve`), secret only in `/etc/pve/priv/storage/pbs-backup.pw` |
| Network | same lab LAN, PBS UI on :8007 reachable only from the LAN |

Deduplication means seven weekly backups of a Windows DC cost little more than one.

## Build notes

### PBS side

```bash
# datastore on the dedicated disk
proxmox-backup-manager disk fs create backup --disk sdb --filesystem ext4 --add-datastore true

# a user and token for the PVE node
proxmox-backup-manager user create pve-backup@pbs
proxmox-backup-manager user generate-token pve-backup@pbs pve

# !! grant the role to BOTH the user and the token (see gotcha below)
proxmox-backup-manager acl update /datastore/backup DatastoreBackup --auth-id pve-backup@pbs
proxmox-backup-manager acl update /datastore/backup DatastoreBackup --auth-id 'pve-backup@pbs!pve'

# retention
proxmox-backup-manager prune-job create weekly-prune --store backup --schedule 'sun 03:00' \
    --keep-weekly 4 --keep-monthly 3
proxmox-backup-manager garbage-collection update backup --schedule 'sun 04:00'   # adjust to taste
```

### PVE side

`/etc/pve/storage.cfg`:

```
pbs: pbs-backup
        datastore backup
        server 192.0.2.31
        content backup
        fingerprint <pbs cert fingerprint>
        prune-backups keep-all=1
        username pve-backup@pbs!pve
```

with the token secret in `/etc/pve/priv/storage/pbs-backup.pw` (mode 600). Then point the existing weekly job at `pbs-backup`, add VM 210, and set the old `local`-based dumps to be removed.

Verify:

```bash
pvesm status                       # pbs-backup active, free space sane
vzdump 210 --storage pbs-backup    # one manual run before trusting the schedule
proxmox-backup-client list --repository 'pve-backup@pbs!pve@192.0.2.31:backup'
```

## Gotchas

1. **Token privileges are capped by the owning user.** Granting `DatastoreBackup` to `pve-backup@pbs!pve` alone produces `permission check failed` on the PVE side. The ACL has to be on the user as well.
2. **`pvesm add pbs … ` without `--password` fails *and deletes* the `.pw` file it was supposed to use.** Write the `storage.cfg` stanza directly and create the password file by hand instead.
3. **Exclude the datastore disk from backups.** Otherwise the first backup of VM 211 tries to archive 250 GB of backups into itself.
4. **`protection=1` on the PBS VM.** The backup server is the one guest a runaway automation token must never be able to destroy. Automation tokens are also overridden to read-only on this VM's path (see [Paperclip AI Agents](https://github.com/Dstanfield-Creator/ai-automation/tree/main/paperclip-ai-agents/)).

## Outcome

- Weekly job running green against `pbs-backup`.
- Stale dumps cleared from `local`; the root disk went from 100% to roughly two-thirds used.
- Still to do: a full restore test of one VM to a scratch VMID, and a monthly check of the prune/GC task log.

## Skills demonstrated

Backup architecture (3-2-1 thinking on a one-node budget) · Proxmox Backup Server administration · PVE/PBS token authentication and ACLs · retention and GC policy · root-cause analysis of a silent failure

## Related

- [Proxmox Lab Platform](../proxmox-lab-platform/) — the node being backed up
- [Paperclip AI Agents](https://github.com/Dstanfield-Creator/ai-automation/tree/main/paperclip-ai-agents/) — the other protected VM, and the automation token design

---

**Author:** Danny Stanfield · Perth, WA  
**License:** MIT
