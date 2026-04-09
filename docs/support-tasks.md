# Project Alexandria — Support Tasks Schedule
**Version:** 1.0.0 | **Author:** Iain Reid | **Date:** 2026-03-30

---

## 1. Automated Tasks (no manual action required)

| Task | Trigger | Owner | Log location |
|:-----|:--------|:------|:-------------|
| Container healthchecks | Podman internal (30–60s interval) | SysAdmin | `podman ps` |
| ZIM integrity verify | Part of sneakernet.sh import | SysAdmin | `/var/log/alexandria/sneakernet.log` |

---

## 2. Weekly Support Tasks (manual)

| # | Task | Owner | Command / Action |
|:--|:-----|:------|:----------------|
| W-1 | Review sneakernet import log for errors | SysAdmin | `cat /var/log/alexandria/sneakernet.log` |
| W-2 | Confirm staging server is not actively connected to ZIM storage | SysAdmin | Verify staging server network state per site security policy |
| W-3 | Confirm all containers healthy | SysAdmin | `podman ps --format "table {{.Names}}\t{{.Status}}"` |
| W-4 | Review container and host audit logs | SysAdmin | `journalctl --since "7 days ago" -u alexandria-*` |

---

## 3. Monthly Support Tasks

| # | Task | Owner | Command / Action |
|:--|:-----|:------|:----------------|
| M-1 | ZFS/LVM pool scrub | SysAdmin | `zpool scrub alexandria` then `zpool status` |
| M-2 | Persona / hallucination audit | AI Architect | Run test prompts per Maintenance Guide §10 |
| M-3 | Dependency version review | AI Architect | `podman exec alexandria-webui pip list --outdated` |
| M-4 | Review security logs (auth, WAN, sneakernet) | SysAdmin | See Maintenance Guide §7 |
| M-5 | Check disk usage on storage pool | SysAdmin | `df -h /mnt/pve/alexandria` |
| M-6 | Verify ChromaDB collection health | AI Architect | `curl http://localhost:8000/api/v1/collections` |
| M-7 | Confirm backup completion (edits + chromadb) | SysAdmin | Review Proxmox Backup Server job logs |

---

## 4. Quarterly Support Tasks

| # | Task | Owner | Command / Action |
|:--|:-----|:------|:----------------|
| Q-1 | Rebuild all container images with updated pins | SysAdmin | See Container Build Guide §7 |
| Q-2 | Rotate `webui_secret_key` Podman secret | SysAdmin | See Maintenance Guide §6 |
| Q-3 | Update Containerfile base image digests | SysAdmin | Verify upstream releases; update FROM lines |
| Q-4 | Full security log review | SysAdmin | Review 90 days of auth, WAN gate, and container logs |
| Q-5 | Update Security Gap Analysis document | SysAdmin + AI Architect | Review GAP register; close resolved items |
| Q-6 | Trivy CVE scan on all images | SysAdmin | `trivy image localhost/alexandria-*:latest` |
| Q-7 | Review and update RBAC / user accounts | SysAdmin | Remove leavers; confirm role assignments |

---

## 5. Annual Support Tasks

| # | Task | Owner | Command / Action |
|:--|:-----|:------|:----------------|
| A-1 | Full DR test | SysAdmin + AI Architect | See Maintenance Guide §9 |
| A-2 | Security compliance review | SysAdmin | Update `security-compliance.md` against latest standard versions |
| A-3 | Architecture review | SysAdmin + AI Architect | Review architecture doc; identify obsolete components |
| A-4 | Refresh all documentation | All | Review and update all docs in `docs/` |

---

## 6. Ad-Hoc Tasks

| Task | Trigger | Owner | Procedure |
|:-----|:--------|:------|:----------|
| ZIM import via sneakernet | New ZIM version available on encrypted USB | SysAdmin | Run `scripts/sneakernet.sh` per PRD §8 |
| New local edit ingest | Researcher adds `.md` file | AI Architect | `podman exec alexandria-webui python /app/backend/tools/ingest_edits.py` |
| Incident response | Security event detected | SysAdmin | Isolate container, preserve logs, notify ISSO within 1 hour |
| Emergency WAN gate close | Anomalous outbound traffic detected on host | SysAdmin | `scripts/toggle_updates.sh close` then investigate |
| User account provisioning | New researcher onboarded | SysAdmin | Create Open WebUI account, set role to `User` |
| User account deprovisioning | Staff departure | SysAdmin | Disable Open WebUI account; remove from `alexandria-admin` if applicable |

---

## 7. Support Contact Matrix

| Issue Type | First Contact | Escalation |
|:-----------|:-------------|:-----------|
| Infrastructure / containers down | SysAdmin | — |
| AI responses incorrect / hallucinating | AI Architect | SysAdmin |
| Content missing from Librarian | Researcher → AI Architect | — |
| Security incident | SysAdmin | ISSO (within 1 hour) |
| Access request | SysAdmin | — |
