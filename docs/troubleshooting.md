# Troubleshooting

Real issues hit while building this stack, and *why* each fix works. This is the part of
the project that reflects actual Linux problem-solving rather than copy-paste setup.

---

## 1. Binaries won't execute after being moved from `/tmp` (SELinux)

**Symptom:** After downloading and moving a binary from `/tmp` into `/usr/local/bin`, the
service fails to start, or execution is denied even though file permissions look correct.

**Cause:** SELinux labels files with a context based on *where they were created*. A file
written in `/tmp` inherits a `tmp_t`-style context. When you `mv` it into `/usr/local/bin`,
the inode keeps its original context (a move preserves labels; a copy with `cp` would
inherit the destination's default). The running confined context then doesn't match what
SELinux policy expects for an executable in that location.

**Fix:** Relabel the file to the default context for its new path:

```bash
restorecon -Rv /usr/local/bin/prometheus
restorecon -Rv /usr/local/bin/alloy
restorecon -Rv /usr/local/grafana
```

`restorecon` resets the SELinux context to what the policy says the path *should* have.
The `-v` flag prints what it changed, which is useful for confirming the relabel actually
happened. (Using `cp` instead of `mv`, or `install`, would have avoided this because the
new file inherits the destination directory's default context.)

---

## 2. Grafana shows "No data" even though Prometheus has metrics (clock drift)

**Symptom:** Prometheus is scraping, Alloy is pushing, yet Grafana panels and even raw
Prometheus queries return empty / "No data" — intermittently or after the VM has been
suspended.

**Cause:** This is a **time** problem, not a metrics problem. Prometheus is a time-series
database: every sample is stamped with a timestamp, and a query like "last 5 minutes"
selects samples whose timestamps fall inside a window anchored to the system clock's idea
of *now*. On a VM (especially one that gets suspended/resumed in VirtualBox), the hardware
clock (RTC) drifts. If the system clock is wrong, the query window no longer overlaps the
timestamps of the samples actually stored, so the query returns nothing — even though the
data is there.

**Fix:** Force a step correction and write the corrected time back to the hardware clock:

```bash
chronyc -a makestep      # immediately step the system clock to correct time
hwclock --systohc        # write the corrected system time back to the RTC
```

`makestep` jumps the clock in one step instead of slewing it slowly (important when the
offset is large). `hwclock --systohc` persists the fix so a reboot doesn't reintroduce the
drift. Note: `chronyc tracking` may still cosmetically show `Leap status` / NTP
synchronised as "no" right after, but the actual time is correct post-`makestep` — verify
with `date` against a known-good source.

---

## 3. Alloy's UI is unreachable from the host

**Symptom:** Services are up, port forwarding/firewall look fine, but you can't open the
Alloy diagnostics UI at `http://<vm-ip>:12345` from your host browser.

**Cause:** By default Alloy binds its HTTP server to `127.0.0.1`, so it only listens on
loopback inside the VM. Nothing outside the VM (including your host) can reach it.

**Fix:** Bind to all interfaces and open the port:

```bash
# In the systemd unit ExecStart:
--server.http.listen-addr=0.0.0.0:12345

# Firewall:
sudo firewall-cmd --permanent --add-port=12345/tcp
sudo firewall-cmd --reload
```

---

## 4. Grafana fails to start when only the binary is in place

**Symptom:** Pointing the service at just `/usr/local/bin/grafana` (or running the binary
alone) fails with missing template / static asset errors.

**Cause:** The Grafana standalone binary depends on its **full extracted directory** —
`conf/`, `public/`, plugins, etc. It is not a single self-contained executable.

**Fix:** Run it with the working directory and home path set to the extracted root:

```ini
WorkingDirectory=/usr/local/grafana
ExecStart=/usr/local/grafana/bin/grafana server \
  --config=/usr/local/grafana/conf/defaults.ini \
  --homepath=/usr/local/grafana
```

---

## 5. Firewall blocks the service ports

**Symptom:** Services listen inside the VM but are unreachable from the host.

**Fix:** Open the three ports in firewalld:

```bash
sudo firewall-cmd --permanent --add-port=9090/tcp    # Prometheus
sudo firewall-cmd --permanent --add-port=12345/tcp   # Alloy UI
sudo firewall-cmd --permanent --add-port=3000/tcp    # Grafana
sudo firewall-cmd --reload
sudo firewall-cmd --list-ports                       # verify
```

---

## Quick diagnostic checklist

| Check | Command |
|-------|---------|
| Is the service running? | `systemctl status <name>` |
| What did it log? | `journalctl -u <name> -e` |
| Is it listening on the port? | `ss -tlnp \| grep <port>` |
| Is SELinux blocking it? | `ausearch -m avc -ts recent` |
| Is the clock correct? | `date` and `chronyc tracking` |
| Is the firewall open? | `firewall-cmd --list-ports` |
