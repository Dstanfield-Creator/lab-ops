# lab-ssh-check

> Parallel reachability and key-auth check for every host in `~/.ssh/config`, with a status column that tells you *why* a host failed.

**Category:** Tools · **Status:** Active · **Language:** Bash (no dependencies beyond OpenSSH and coreutils)

## Why

With a dozen SSH aliases spread across a LAN, a tailnet, and a hypervisor, "is everything reachable?" was a manual loop of `ssh host true`. Worse, a failure could mean five different things: DNS, host down, host up but no key accepted, host key changed (which should be alarming), or first contact. This script checks all hosts in parallel and classifies each result.

## Usage

```
lab-ssh-check                 # check every alias in ~/.ssh/config
lab-ssh-check pve mcserver    # check just these
lab-ssh-check --quiet         # only print problems (cron / loop friendly)
lab-ssh-check --serial        # one at a time, for readable debugging
lab-ssh-check --all           # include hosts listed in SKIP
```

Exit code is `0` only if every checked host authenticates with a key. Hosts in the `SKIP` array (known-down or decommissioned) are reported as `[SKIP]` and excluded from the exit code, so a cron run only alarms on hosts that are meant to be up. Naming a skipped host explicitly still checks it.

## Example output

```
Checking 8 host(s) from /home/user/.ssh/config

  ALIAS        TARGET                                 STATUS    DETAIL
  -----        ------                                 ------    ------
  pve          admin@192.0.2.10:22                    [OK]      key auth in 180ms
  old-pi       pi@192.0.2.123:2222                    [DOWN]    port 2222 refused or unreachable
  docker-host  admin@192.0.2.20:22                    [OK]      key auth in 280ms
  desktop      admin@desktop.example.ts.net:22        [AUTH]    reachable, but no key accepted
  laptop       user@laptop.example.ts.net:22          [OK]      key auth in 546ms
  mcserver     mc@192.0.2.50:22                       [OK]      key auth in 276ms
  roaming      user@100.64.0.9:22                     [DOWN]    no answer on port 22 (4s timeout)
  attackbox    op@attackbox:22                        [OK]      key auth in 166ms

6/8 host(s) reachable with key auth.
```

## Status codes

| Status | Meaning | Next step |
|---|---|---|
| `OK` | TCP open and key auth succeeded (`BatchMode=yes`, so a password can never be the reason it passed) | — |
| `DOWN` | TCP connect refused or timed out | Host off, firewall, wrong port |
| `DNS` | Hostname did not resolve | MagicDNS / resolver issue |
| `AUTH` | Reachable, but no key accepted | Key not in `authorized_keys`, agent not running |
| `HOSTKEY` | Not in `known_hosts` yet | First contact: connect manually once |
| `HOSTKEY!` | **Host key changed** | Investigate before connecting. Reinstall, or MITM |
| `CONFIG` | Alias has no `HostName` | Fix `~/.ssh/config` |
| `ERR` | Anything else, first 70 chars of stderr shown | Read the detail |
| `SKIP` | In the `SKIP` list | — |

## How it works

1. Parses `Host` stanzas out of `~/.ssh/config` with `awk`, ignoring wildcard patterns.
2. For each alias, resolves the effective `hostname`/`port`/`user` with `ssh -G`, so it honours `Match` blocks, includes and jump hosts exactly as `ssh` would.
3. **TCP probe first** using bash's `/dev/tcp` under `timeout`. This is cheap and separates DNS / DOWN from AUTH before SSH gets involved.
4. **SSH probe** with `BatchMode=yes` (no prompts allowed) and `StrictHostKeyChecking=ask`, timing the handshake in milliseconds, then pattern-matches stderr into the status table above.
5. Runs every host in a background subshell writing one record to a temp dir, then prints an aligned table.

### Gotchas that are handled

- A bare `trap … EXIT` is inherited by background subshells, so each finishing job would delete the shared temp dir. The child clears the trap first.
- `getent` returns 2 for plain IPv4 literals, so resolution failure is read from the connect error instead.
- `date +%3N` is not honoured on every box; nanoseconds are divided down instead.

## Install

```bash
install -m 755 lab-ssh-check ~/bin/
# optional: list known-down aliases in the SKIP array at the top of the script
# optional cron, every morning, only noisy on failure:
# 0 8 * * *  $HOME/bin/lab-ssh-check --quiet || notify-send "lab-ssh-check" "a host failed"
```

## Related

- [Tailscale Remote Access](https://github.com/Dstanfield-Creator/network/tree/main/remote-access/tailscale-remote-access/) — why most targets are tailnet names, not LAN IPs
- [Lab Power Scripts](../lab-power-scripts/) — run this after `lab-up`

---

**Author:** Danny Stanfield · Perth, WA  
**License:** MIT
