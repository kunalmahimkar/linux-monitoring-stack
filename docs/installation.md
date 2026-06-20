# Installation runbook

Target: CentOS Stream 9 (also works on RHEL 9 / Rocky / Alma). Run as root or with `sudo`.

> `scripts/install.sh` automates steps 2–5 and 7. This document explains each step so you
> understand what the script does and can do it by hand if you prefer.

---

## 1. Download the binaries

Pick the versions you want from the official sources and place them as below. Download to
a working dir and **use `install`/`cp` into place** (or `restorecon` afterwards — see
troubleshooting note #1 on SELinux contexts).

- **Prometheus** — https://prometheus.io/download/ → extract → `prometheus` binary
- **Grafana Alloy** — https://github.com/grafana/alloy/releases → `alloy` binary
- **Grafana** — https://grafana.com/grafana/download (standalone binary `.tar.gz`)

```bash
# Prometheus
tar xzf prometheus-*.tar.gz
sudo install -o prometheus -g prometheus prometheus-*/prometheus /usr/local/bin/

# Alloy
sudo install -o alloy -g alloy alloy-linux-amd64 /usr/local/bin/alloy

# Grafana (extract the WHOLE directory, it is not a single binary)
sudo tar xzf grafana-*.tar.gz -C /usr/local/
sudo mv /usr/local/grafana-* /usr/local/grafana
sudo chown -R grafana:grafana /usr/local/grafana

# If you used mv instead of install/cp from /tmp, relabel for SELinux:
sudo restorecon -Rv /usr/local/bin/prometheus /usr/local/bin/alloy /usr/local/grafana
```

## 2. Create dedicated system users

```bash
sudo useradd --system --no-create-home --shell /sbin/nologin prometheus
sudo useradd --system --no-create-home --shell /sbin/nologin alloy
sudo useradd --system --no-create-home --shell /sbin/nologin grafana
```

## 3. Create directories and set ownership

```bash
sudo mkdir -p /etc/prometheus /var/lib/prometheus
sudo mkdir -p /etc/alloy /var/lib/alloy/data
sudo chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus
sudo chown -R alloy:alloy /etc/alloy /var/lib/alloy
```

## 4. Drop in the configs

```bash
sudo cp configs/prometheus/prometheus.yml /etc/prometheus/
sudo cp configs/alloy/config.alloy        /etc/alloy/
sudo chown prometheus:prometheus /etc/prometheus/prometheus.yml
sudo chown alloy:alloy /etc/alloy/config.alloy
```

## 5. Install the systemd units

```bash
sudo cp systemd/prometheus.service systemd/alloy.service systemd/grafana.service \
        /etc/systemd/system/
sudo systemctl daemon-reload
```

## 6. Open the firewall

```bash
sudo firewall-cmd --permanent --add-port=9090/tcp
sudo firewall-cmd --permanent --add-port=12345/tcp
sudo firewall-cmd --permanent --add-port=3000/tcp
sudo firewall-cmd --reload
```

## 7. Enable and start

```bash
sudo systemctl enable --now prometheus
sudo systemctl enable --now alloy
sudo systemctl enable --now grafana

# Verify
systemctl status prometheus alloy grafana
ss -tlnp | grep -E '9090|12345|3000'
```

## 8. Configure Grafana

1. Open `http://<vm-ip>:3000`, log in with `admin` / `admin`, change the password.
2. Add data source → Prometheus → URL `http://localhost:9090` → Save & test.
3. Dashboards → Import → upload `dashboards/dashboard2.json` → select the Prometheus data
   source.
4. Confirm the RAM and CPU panels populate. If they show "No data", check the clock
   (troubleshooting note #2).

## 9. Set up the alert

Follow `alerts/cpu-high-usage.md` to create the CPU-high alert, then test it with
`yes > /dev/null &`.
