# Grafana configuration

Grafana is installed from the standalone binary archive extracted to `/usr/local/grafana/`.
Its default configuration lives at `/usr/local/grafana/conf/defaults.ini`.

For per-instance overrides, create `/usr/local/grafana/conf/custom.ini` (Grafana reads
`custom.ini` on top of `defaults.ini`) rather than editing `defaults.ini` directly — that
keeps your changes separate from the shipped defaults and survives upgrades.

## Data source

After first login (default `admin` / `admin`, change immediately), add the Prometheus
data source manually, or provision it declaratively:

`/usr/local/grafana/conf/provisioning/datasources/prometheus.yaml`

```yaml
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://localhost:9090
    isDefault: true
```

## Why not commit grafana.ini / grafana.db?

They contain instance-specific state (the admin password hash, the SQLite database with
users and sessions). They are intentionally excluded via `.gitignore` and should never be
pushed to a public repo.
