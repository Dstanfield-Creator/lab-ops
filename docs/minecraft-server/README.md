# Minecraft Server

> A systemd-managed Java Minecraft server on a dedicated bare-metal box, reachable over Tailscale rather than a port-forward, and started and stopped as part of the lab.

**Category:** Homelab · **Status:** Active · **Host:** bare metal on the lab LAN (not a VM) · **Access:** Tailscale, no port-forward

## Why it is in a SecOps homelab

Because it is the one service other people depend on, which makes it the best test of the lab's operational habits: it has to come up cleanly, shut down without corrupting the world, stay patched, and be reachable without exposing anything to the internet.

## What is in place

| | |
|---|---|
| Host | dedicated small PC on the lab LAN, Linux, on the tailnet as `mcserver` |
| Service | `minecraft.service`, started and stopped with `systemctl` |
| Lifecycle | [`lab-up`](../../scripts/lab-power-scripts/) starts the service over SSH and confirms it is `active`; `lab-down` stops it **before** the hypervisor goes down |
| Access | players connect over Tailscale; nothing is forwarded on the home router |
| Health | `lab-ssh-check` covers the host; `lab-up`'s log is where "could not reach mcserver" shows up first, as it did on one October morning |

## Reference unit

A hardened unit of the shape used here. `SIGINT` lets the server save the world and disconnect players before the JVM exits.

```ini
[Unit]
Description=Minecraft server
After=network-online.target
Wants=network-online.target

[Service]
User=minecraft
Group=minecraft
WorkingDirectory=/opt/minecraft
ExecStart=/usr/bin/java -Xms2G -Xmx6G -XX:+UseG1GC -XX:+ParallelRefProcEnabled \
    -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC \
    -jar server.jar nogui
KillSignal=SIGINT
TimeoutStopSec=90
Restart=on-failure
RestartSec=10
NoNewPrivileges=true
ProtectSystem=strict
ReadWritePaths=/opt/minecraft
PrivateTmp=true

[Install]
WantedBy=multi-user.target
```

## Operations

- **Start / stop:** `sudo systemctl start|stop minecraft`, or let `lab-up` / `lab-down` do it.
- **Upgrade:** stop the service, swap `server.jar`, start, watch `journalctl -fu minecraft` for the version line.
- **Backups (planned):** nightly `rsync` of the world directory to the Docker host, kept 14 days. The host sits outside Proxmox, so PBS does not cover it.
- **Settings:** allowlist on, online mode on, RCON off. Tailscale is the perimeter; the server's own settings are the second layer.

## Design notes

- **Order the shutdown.** `lab-down` stops the game server first so the world is saved before anything else goes away.
- **A graceful signal, with time.** `SIGINT` and a 90 s stop timeout give the server room to flush chunks.
- **Tailscale instead of a port-forward.** Inviting a device to the tailnet is easier than any port-forward and leaves nothing exposed.

## Skills demonstrated

systemd service hardening · JVM tuning · Tailscale access · lifecycle automation · runbooks

## Related

- [Lab Power Scripts](../../scripts/lab-power-scripts/) · [Tailscale Remote Access](https://github.com/Dstanfield-Creator/network/tree/main/remote-access/tailscale-remote-access/) · [Docker Services Host](../docker-services-host/) (planned backup target)

---

**Author:** Danny Stanfield · Perth, WA  
**License:** MIT
