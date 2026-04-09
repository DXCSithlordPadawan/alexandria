# Project Alexandria — Deployment Guide
**Version:** 1.0.0 | **Author:** Iain Reid | **Date:** 2026-03-30
**Target Platform:** Proxmox 9.1 (Debian 13) | **Container Runtime:** Rootless Podman

---

## 1. Pre-Deployment Checklist

Before starting, confirm the following on the Proxmox host:

- [ ] Proxmox 9.1 installed and updated (`apt update && apt full-upgrade`)
- [ ] FIPS mode enabled: `cat /proc/sys/crypto/fips_enabled` returns `1`
- [ ] Kernel parameter set: `fips=1` in `/etc/default/grub`, `update-grub` run
- [ ] ZFS or LVM storage pool created at `/mnt/pve/alexandria`
- [ ] LUKS2 encryption applied to storage pool (validated modules only)
- [ ] Rootless Podman installed: `podman --version` (≥ 5.0)
- [ ] `podman-compose` installed: `pip install podman-compose`
- [ ] `alexandria` system user created (no login shell)
- [ ] `alexandria-admin` group created, SysAdmin account added

---

## 2. Storage Preparation

```bash
# Create directory structure on Proxmox storage pool
mkdir -p /mnt/pve/alexandria/{zim,edits,chromadb,ollama}
chown -R alexandria:alexandria /mnt/pve/alexandria
chmod 750 /mnt/pve/alexandria

# Verify LUKS encryption on the pool's backing device
cryptsetup status /dev/mapper/alexandria-pool
```

---

## 3. Repository Deployment

```bash
# Clone to /opt/alexandria (or copy from encrypted media for air-gapped environments)
git clone https://your-git-host/alexandria.git /opt/alexandria
cd /opt/alexandria
chown -R root:alexandria /opt/alexandria
chmod -R 750 /opt/alexandria
chmod +x scripts/*.sh
```

---

## 4. Environment Configuration

```bash
# Copy and edit the environment template
cp /opt/alexandria/config/.env.example /opt/alexandria/config/.env
chmod 640 /opt/alexandria/config/.env
chown root:alexandria /opt/alexandria/config/.env

# Edit values — at minimum set:
#   ZIM_PATH, EDITS_PATH, CHROMA_DATA_PATH, OLLAMA_MODEL
nano /opt/alexandria/config/.env
```

---

## 5. Podman Secret Setup

The WebUI secret key must never appear in environment files. Use `podman secret`:

```bash
# Generate a strong random key
openssl rand -hex 32 | podman secret create webui_secret_key -

# Verify the secret is registered
podman secret ls
```

---

## 6. Systemd Timer Installation

```bash
# Copy units to systemd
cp /opt/alexandria/config/systemd/alexandria-sync.service /etc/systemd/system/
cp /opt/alexandria/config/systemd/alexandria-sync.timer  /etc/systemd/system/

# Reload, enable and start the timer
systemctl daemon-reload
systemctl enable --now alexandria-sync.timer

# Verify
systemctl status alexandria-sync.timer
systemctl list-timers alexandria-sync.timer
```

---

## 7. Firewall Security Group

On the Proxmox host, create the WAN gate security group:

```bash
# In the Proxmox web UI: Datacenter → Firewall → Security Groups → Add
# Name: alexandria-wan
# Add rules as defined in config/firewall/wan-gate.rules
# Leave the group DISABLED by default

# Apply to the VM/CT NIC running Alexandria containers
# Datacenter → <VM> → Firewall → Add Security Group → alexandria-wan
```

---

## 8. First ZIM Download

The initial Wikipedia ZIM (~120 GB) requires the WAN gate to be open. Schedule this during an approved maintenance window.

```bash
# Open WAN gate (SysAdmin only)
/opt/alexandria/scripts/toggle_updates.sh open

# Start the download manually (runs in foreground; use tmux/screen)
ZIM_PATH=/mnt/pve/alexandria/zim \
ZIM_FILE=wikipedia_en_all_maxi.zim \
KIWIX_MIRROR=https://download.kiwix.org/zim/wikipedia/ \
  /opt/alexandria/scripts/sync_wiki.sh

# When complete, close WAN gate immediately
/opt/alexandria/scripts/toggle_updates.sh close

# Verify integrity
/opt/alexandria/scripts/verify_zim.sh /mnt/pve/alexandria/zim
```

---

## 9. Build and Start Containers

```bash
cd /opt/alexandria/config

# Build all images (first run; subsequent runs use layer cache)
podman-compose --env-file .env build

# Start all services
podman-compose --env-file .env up -d

# Verify all containers are healthy
podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

Expected output — all containers showing `healthy`:
```
NAMES                    STATUS                    PORTS
alexandria-wiki          Up 2 minutes (healthy)
alexandria-sync          Up 2 minutes
alexandria-chroma        Up 2 minutes (healthy)
alexandria-ollama        Up 2 minutes (healthy)
alexandria-webui         Up 2 minutes (healthy)    127.0.0.1:3000->8080/tcp
```

---

## 10. First-Run AI Setup

```bash
# Pull the LLM model (requires network or pre-cached blobs)
podman exec alexandria-ollama ollama pull llama3.2

# Ingest any existing local edit files into ChromaDB
podman exec alexandria-webui \
  python /app/backend/tools/ingest_edits.py \
  --edits-dir /data/edits \
  --chroma-host chromadb
```

---

## 11. Reverse Proxy (TLS)

The WebUI binds to `127.0.0.1:3000` only. Expose it externally via nginx or Caddy with TLS:

```nginx
# /etc/nginx/sites-available/alexandria
server {
    listen 443 ssl http2;
    server_name alexandria.internal;

    ssl_certificate     /etc/ssl/alexandria/cert.pem;
    ssl_certificate_key /etc/ssl/alexandria/key.pem;
    ssl_protocols       TLSv1.3;
    ssl_ciphers         TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256;

    location / {
        proxy_pass         http://127.0.0.1:3000;
        proxy_set_header   Host $host;
        proxy_set_header   X-Real-IP $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto https;
        proxy_read_timeout 300s;
    }
}
```

---

## 12. Smoke Test

```bash
# 1. Kiwix responding
curl -s http://localhost:8080/catalog/root.xml | head -5

# 2. ChromaDB heartbeat
curl -s http://localhost:8000/api/v1/heartbeat

# 3. Ollama model list
curl -s http://localhost:11434/api/tags | python3 -m json.tool

# 4. WebUI reachable
curl -so /dev/null -w "%{http_code}" http://localhost:3000/health
# Expected: 200
```

---

## 13. Post-Deployment Hardening Checklist

- [ ] `podman-compose` logs reviewed — no errors
- [ ] `verify_zim.sh` passed
- [ ] WebUI accessible via HTTPS only (HTTP redirects to HTTPS)
- [ ] WAN gate confirmed CLOSED (`pvesh get /cluster/firewall/groups/alexandria-wan`)
- [ ] Systemd timer next-run date confirmed (`systemctl list-timers`)
- [ ] Ollama model loaded and responding to test query
- [ ] ChromaDB collection `local_edits` exists (even if empty)
- [ ] Log rotation configured for `/var/log/alexandria/`
