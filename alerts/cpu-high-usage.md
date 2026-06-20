# Alert: CPU High Usage

A Grafana **managed alert** that fires when host CPU usage stays above 80%.

## Rule definition

| Setting | Value |
|---------|-------|
| Name | CPU High Usage |
| Query (PromQL) | `100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)` |
| Condition | `IS ABOVE 80` |
| Evaluation group | `vm-eval` |
| Evaluation interval | every `30s` |
| Pending period | `20s` |
| Folder | `vm-monitoring` |
| Contact point | `grafana-default-email` |

The pending period means the metric must stay above threshold for 20s before the alert
transitions from **Pending** to **Firing** — this avoids alerting on a momentary spike.

## How it was tested

```bash
# Spike CPU: 'yes' writes "y" as fast as possible, discarded to /dev/null,
# pinning a core at ~100%.
yes > /dev/null &

# Watch CPU climb to ~85% in Grafana. After the pending period the alert fires
# and a notification is sent to the grafana-default-email contact point.

# Stop the load:
kill %1
# (or: pkill yes)
```

## Exporting the rule for the repo

In Grafana 11 you can export the alert rule as provisioning YAML:
**Alerting → Alert rules → (rule) → Export → YAML**. Save it next to this file as
`cpu-high-usage.provisioning.yaml` so the rule is reproducible from version control.
