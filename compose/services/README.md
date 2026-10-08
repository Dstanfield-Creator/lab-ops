# services

Core self-hosted services as a single Compose stack: a reverse proxy, a
workflow automation engine, and a status page.

## What runs here

| Service           | Image                              | Published port         |
| ----------------- | ---------------------------------- | ---------------------- |
| Nginx Proxy Mgr   | `jc21/nginx-proxy-manager:2.12.1`  | `80`, `443`, `:81` (lo) |
| n8n               | `n8nio/n8n:1.70.0`                  | none (behind proxy)    |
| Uptime Kuma       | `louislam/uptime-kuma:1.23.16`     | none (behind proxy)    |

Nginx Proxy Manager terminates TLS and routes to the other services over the
internal `edge` network; its admin UI is bound to loopback only. n8n and
Uptime Kuma publish no host ports and are reached through the proxy.

## Usage

```bash
cp .env.example .env        # then set N8N_ENCRYPTION_KEY and hostnames
docker compose pull
docker compose up -d
docker compose ps
```

Image tags are pinned and tracked by Renovate. Secrets (the n8n encryption
key, any proxy credentials) live only in the local `.env` - see `.env.example`.
