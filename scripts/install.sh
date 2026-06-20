#!/usr/bin/env bash
#
# install.sh — provision the monitoring stack scaffolding on CentOS Stream 9 / RHEL 9.
#
# This script creates the system users, directories, permissions, installs the systemd
# units and the configs, opens the firewall, and reloads systemd. It does NOT download
# the binaries — place those first (see docs/installation.md step 1).
#
# Run as root:  sudo ./scripts/install.sh
#
set -euo pipefail

# Resolve repo root regardless of where the script is called from
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root (use sudo)." >&2
  exit 1
fi

echo "==> Creating system users (idempotent)"
for user in prometheus alloy grafana; do
  if id "$user" &>/dev/null; then
    echo "    user '$user' already exists, skipping"
  else
    useradd --system --no-create-home --shell /sbin/nologin "$user"
    echo "    created user '$user'"
  fi
done

echo "==> Creating directories"
mkdir -p /etc/prometheus /var/lib/prometheus
mkdir -p /etc/alloy /var/lib/alloy/data
chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus
chown -R alloy:alloy /etc/alloy /var/lib/alloy

echo "==> Installing configs"
install -o prometheus -g prometheus -m 0644 \
  "${REPO_ROOT}/configs/prometheus/prometheus.yml" /etc/prometheus/prometheus.yml
install -o alloy -g alloy -m 0644 \
  "${REPO_ROOT}/configs/alloy/config.alloy" /etc/alloy/config.alloy

echo "==> Installing systemd units"
install -m 0644 "${REPO_ROOT}/systemd/prometheus.service" /etc/systemd/system/
install -m 0644 "${REPO_ROOT}/systemd/alloy.service"      /etc/systemd/system/
install -m 0644 "${REPO_ROOT}/systemd/grafana.service"    /etc/systemd/system/
systemctl daemon-reload

echo "==> Relabelling binaries for SELinux (if present)"
for path in /usr/local/bin/prometheus /usr/local/bin/alloy /usr/local/grafana; do
  if [[ -e "$path" ]]; then
    restorecon -Rv "$path" || true
  else
    echo "    WARNING: $path not found — download/place the binary (see docs/installation.md)"
  fi
done

echo "==> Opening firewall ports (9090, 12345, 3000)"
if command -v firewall-cmd &>/dev/null; then
  firewall-cmd --permanent --add-port=9090/tcp
  firewall-cmd --permanent --add-port=12345/tcp
  firewall-cmd --permanent --add-port=3000/tcp
  firewall-cmd --reload
else
  echo "    firewalld not found — open ports 9090/12345/3000 with your firewall manually"
fi

echo
echo "==> Scaffolding complete."
echo "    Next: ensure the binaries are in place, then:"
echo "      sudo systemctl enable --now prometheus alloy grafana"
echo "      systemctl status prometheus alloy grafana"
