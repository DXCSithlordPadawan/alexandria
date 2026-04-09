# Project Alexandria — Maintenance Guide
**Version:** 1.0.0 | **Author:** Iain Reid | **Date:** 2026-03-30

---

## 1. Maintenance Schedule

| Frequency | Task | Owner | Script / Command |
|:----------|:-----|:------|:----------------|
| Weekly (automated) | ZIM sync + checksum verify | SysAdmin | `alexandria-sync.timer` |
| Weekly (automated) | Container health check | SysAdmin | `podman ps` / healthchecks |
| Monthly | ZFS/LVM pool scrub | SysAdmin | `zpool scrub alexandria` |
| Monthly | Dependency version review | AI Architect | See §4 |
| Monthly | Ollama persona audit | AI Architect | `persona_test.py` |
| Quarterly | Container image rebuild (pin updates) | SysAdmin | See §5 |
| Quarterly | Podman secret rotation | SysAdmin | See §6 |
| Quarterly | Security log review | SysAdmin | See §7 |
| Annually | Full DR test | SysAdmin + AI Architect | See §8 |

---

## 2. Weekly ZIM Sync (Automated)

The `alexandria-sync.timer` fires every Sunday at 02:00. No manual action required under normal conditions.

**To check last sync result:**
```bash
journalctl -u alexandria-sync.service --since "7 days ago" | grep -E "PASS|FAIL|ERROR"
```

**To trigger a manual sync immediately (SysAdmin only):**
```bash
systemctl start alexandria-sync.service
```

**To verify the current ZIM manually:**
```bash
/opt/alexandria/scripts/verify_zim.sh /mnt/pve/alexandria/zim
```

---

## 3. Adding Local Edits

Researchers add Markdown files to `/mnt/pve/alexandria/edits/`. After adding or modifying files, the RAG index must be updated:

```bash
# Re-ingest only changed files (incremental — safe to run anytime)
podman exec alexandria-webui \
  python /app/backend/tools/ingest_edits.py

# Force full re-ingest (use after bulk changes)
podman exec alexandria-webui \
  python /app/backend/tools/ingest_edits.py --force
```

**Markdown file conventions:**

- First line must be a level-1 heading: `# Title of the Edit`
- Keep files focused on a single topic for best RAG retrieval
- Filenames use kebab-case: `my-topic-correction.md`
- Files exceeding 10,000 characters are chunked automatically

---

## 4. Monthly Dependency Review

Check for security advisories on pinned versions:

```bash
# Check Python dependencies in openwebui container
podman exec alexandria-webui pip list --outdated

# Check image digests against upstream
podman image inspect alexandria-wiki --format '{{.Digest}}'
# Compare against: https://github.com/kiwix/kiwix-tools/releases

# Review CVEs for pinned Alpine version
# https://www.alpinelinux.org/releases/
```

Update pins in Containerfiles only after testing in a non-production environment.

---

## 5. Quarterly Container Rebuild

```bash
cd /opt/alexandria/config

# Pull updated base images
podman-compose --env-file .env pull

# Rebuild with updated pins
podman-compose --env-file .env build --no-cache

# Rolling restart (zero-downtime where possible)
podman-compose --env-file .env up -d --force-recreate

# Verify health
podman ps --format "table {{.Names}}\t{{.Status}}"
```

---

## 6. Podman Secret Rotation

```bash
# Generate a new secret
NEW_KEY=$(openssl rand -hex 32)

# Remove old secret (requires containers to be stopped)
podman-compose --env-file .env down
podman secret rm webui_secret_key

# Create new secret
printf '%s' "${NEW_KEY}" | podman secret create webui_secret_key -

# Restart services
podman-compose --env-file .env up -d

# Securely destroy the variable
unset NEW_KEY
```

---

## 7. Security Log Review

```bash
# WAN gate activity (open/close events)
cat /var/log/alexandria/wan-gate.log

# Sneakernet import log
cat /var/log/alexandria/sneakernet.log

# Container logs (last 24h)
podman logs --since 24h alexandria-webui
podman logs --since 24h alexandria-sync
podman logs --since 24h alexandria-ollama

# System auth log (SSH access to host)
journalctl -u sshd --since "30 days ago"
```

---

## 8. Backup Strategy

| Data | Backup method | Frequency | Retention |
|:-----|:-------------|:----------|:----------|
| `/mnt/pve/alexandria/edits/` | Proxmox Backup Server snapshot | Daily | 30 days |
| `/mnt/pve/alexandria/chromadb/` | vzdump or rsync | Daily | 7 days |
| `/opt/alexandria/` (config + scripts) | Git repository | On change | Indefinite |
| `/mnt/pve/alexandria/zim/*.zim` | **Not backed up** — reproducible from Kiwix | — | — |

**Backup verification:**
```bash
# Test restore of edits directory
vzdump --dumpdir /tmp/test-restore --mode snapshot <VMID>
```

---

## 9. DR Test Procedure (Annual)

1. Provision a fresh Proxmox VM
2. Follow Deployment Guide from scratch using only the Git repository
3. Restore `/data/edits` from backup
4. Run `ingest_edits.py --force`
5. Execute all smoke tests from Deployment Guide §12
6. Confirm Librarian responses match expected outputs from `persona_test.py`
7. Document test date and result in change log

---

## 10. Persona / Hallucination Audit

Monthly check to ensure the Librarian adheres to its citation and hallucination guardrails.

**Manual test prompts:**
- `"What is the capital of France?"` → must return `[Wikipedia]` result
- `"Tell me about Project Zephyr"` → if not in edits, must return the not-found guard string
- Ask a question covered by a local edit → must return `[Local Edit]` result, not Wikipedia

**Automated (placeholder for future implementation):**
```bash
# persona_test.py to be implemented in Sprint 2
python /opt/alexandria/scripts/persona_test.py
```
