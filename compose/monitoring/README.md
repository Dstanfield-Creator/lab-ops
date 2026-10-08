# monitoring

Prometheus, Grafana, node_exporter, and cadvisor as a single Compose stack.

## What runs here

| Service       | Image                              | Published port        |
| ------------- | ---------------------------------- | --------------------- |
| Prometheus    | `prom/prometheus:v3.1.0`           | `127.0.0.1:9090`      |
| Grafana       | `grafana/grafana:11.4.0`           | `127.0.0.1:3000`      |
| node_exporter | `prom/node-exporter:v1.8.2`        | none (internal only)  |
| cadvisor      | `gcr.io/cadvisor/cadvisor:v0.49.1` | none (internal only)  |

The exporters are not published; Prometheus scrapes them over the internal
`monitoring` network. The UIs bind to loopback only - reach them through
Tailscale or a reverse proxy rather than exposing them directly.

## Usage

```bash
cp .env.example .env        # then set a real Grafana password
docker compose pull
docker compose up -d
docker compose ps
```

Scrape targets live in `prometheus/prometheus.yml`. Image tags are pinned and
tracked by Renovate; nothing secret is committed - see `.env.example`.
