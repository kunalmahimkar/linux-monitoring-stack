# Architecture

## Components and data flow

```
  HOST KERNEL / PROC
        │  (reads /proc, /sys)
        ▼
  ┌──────────────────────┐
  │  Grafana Alloy        │   prometheus.exporter.unix  → node metrics
  │  user: alloy          │   prometheus.scrape         → every 15s
  │  :12345 (diag UI)     │   prometheus.remote_write   → push
  └──────────┬───────────┘
             │  HTTP POST  /api/v1/write
             ▼
  ┌──────────────────────┐
  │  Prometheus           │   stores samples in TSDB (/var/lib/prometheus)
  │  user: prometheus     │   remote-write receiver ENABLED
  │  :9090                │   serves PromQL queries
  └──────────┬───────────┘
             │  PromQL over HTTP
             ▼
  ┌──────────────────────┐
  │  Grafana 11.2.0       │   Prometheus data source @ http://localhost:9090
  │  user: grafana        │   dashboard2 (RAM + CPU panels)
  │  :3000                │   managed alert (CPU > 80%)
  └──────────────────────┘
```

## Why push (remote_write) instead of pull (scrape)?

The classic Prometheus model is *pull*: Prometheus reaches out and scrapes a
`node_exporter` endpoint. This project instead uses Grafana Alloy as the collector, which
runs the unix exporter internally and **pushes** to Prometheus via `remote_write`. This
mirrors the direction Grafana's tooling has moved (Agent → Alloy) and keeps a single
collector binary responsible for gathering and shipping metrics.

The trade-off worth knowing: pull makes Prometheus the source of truth for "what targets
exist" and gives free up/down detection via the scrape itself; push centralises
collection in the agent and works better when the agent can reach the backend but not
vice-versa. Here, both run on the same host, so it's primarily a demonstration of the
Alloy pipeline.

## Filesystem layout (FHS)

| Path | Purpose |
|------|---------|
| `/usr/local/bin/prometheus`, `/usr/local/bin/alloy` | Executables not managed by the OS package manager |
| `/usr/local/grafana/` | Full Grafana distribution (binary + conf + public) |
| `/etc/prometheus/`, `/etc/alloy/` | Configuration |
| `/var/lib/prometheus/`, `/var/lib/alloy/` | Persistent state (TSDB, WAL) |
| `/etc/systemd/system/*.service` | Unit files |

`/usr/local` is the correct home for software installed manually (outside the distro's
package manager), which is exactly what building from binaries is.

## Service identity & hardening

Each component runs as its own non-login system user (`prometheus`, `alloy`, `grafana`)
created with `--system --shell /sbin/nologin`. Running as dedicated unprivileged users
means a compromise of one service is contained and none of them run as root. The units
add `NoNewPrivileges`, `ProtectHome`, and `ProtectSystem` where compatible.
