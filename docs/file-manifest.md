# Project Alexandria — File Manifest
**Version:** 1.0.0 | **Author:** Iain Reid | **Date:** 2026-03-30

---

## 1. Repository Root

| File | Type | Purpose |
|:-----|:-----|:--------|
| `.gitignore` | Config | Git exclusion rules — excludes ZIM, edits, .env, venv |
| `Alexandria_PRD.md` | Document | Original Product Requirements Document |
| `PROGRESS.md` | Tracker | Session progress log |

---

## 2. config/

| File | Type | Purpose |
|:-----|:-----|:--------|
| `config/.env.example` | Config template | Environment variable template — copy to `.env` before use |
| `config/podman-compose.yml` | Orchestration | Rootless Podman Compose — defines all 4 services (updater removed) |
| `config/systemd/alexandria-sync.timer` | Systemd unit | Timer: sneakernet import verification (on-demand) |
| `config/systemd/alexandria-sync.service` | Systemd unit | Service: ZIM integrity verification after sneakernet import |
| `config/firewall/wan-gate.rules` | Firewall | Proxmox pve-firewall rules for host-level policies |
| `config/traefik/traefik.yml` | Config | Traefik v3 static configuration (entrypoints, PKI resolver, metrics) |
| `config/traefik/dynamic/alexandria.yml` | Config | Traefik v3 dynamic config — routers, services, middlewares for Alexandria |
| `config/prometheus/prometheus.yml` | Config | Prometheus scrape configuration for all Alexandria components |
| `config/grafana/provisioning/datasources/prometheus.yml` | Config | Grafana datasource provisioning — Alexandria Prometheus |
| `config/grafana/provisioning/dashboards/dashboard.yml` | Config | Grafana dashboard provisioning — folder and org settings |
| `config/grafana/dashboards/alexandria.json` | Dashboard | Grafana dashboard — Project Alexandria System Overview |

---

## 2a. .github/

| File | Type | Purpose |
|:-----|:-----|:--------|
| `.github/workflows/alexandria-pipeline.yml` | CI/CD | GitHub Actions pipeline — validate, security scan, build containers with Podman, trivy CVE scan, deploy configs |

---

### kiwix/

| File | Type | Purpose |
|:-----|:-----|:--------|
| `services/kiwix/Containerfile` | Container | Hardened Kiwix Wikipedia reader image |

### updater/

> **Removed:** The `updater` sidecar container has been removed. ZIM files are now imported exclusively via the sneakernet protocol (`scripts/sneakernet.sh`).

### chromadb/

| File | Type | Purpose |
|:-----|:-----|:--------|
| `services/chromadb/Containerfile` | Container | Hardened ChromaDB vector store |

### ollama/

| File | Type | Purpose |
|:-----|:-----|:--------|
| `services/ollama/Containerfile` | Container | Ollama LLM inference engine |

### openwebui/

| File | Type | Purpose |
|:-----|:-----|:--------|
| `services/openwebui/Containerfile` | Container | Open WebUI with Librarian tool baked in |
| `services/openwebui/librarian_tool.py` | Python | Open WebUI Tool — queries Kiwix + ChromaDB with citation and priority logic |
| `services/openwebui/ingest_edits.py` | Python | CLI tool — walks /data/edits, embeds Markdown, upserts into ChromaDB |

---

## 4. scripts/

| File | Type | Purpose |
|:-----|:-----|:--------|
| `scripts/sync_wiki.sh` | Shell | Downloads ZIM + sha256, verifies, atomically replaces (for use on staging server) |
| `scripts/verify_zim.sh` | Shell | Standalone ZIM integrity checker (manual or post-import) |
| `scripts/toggle_updates.sh` | Shell | WAN gate open/close via pvesh — deprecated for automated use; manual override only |
| `scripts/sneakernet.sh` | Shell | **Primary ZIM acquisition** — physical media import with integrity verification |

---

## 5. docs/

| File | NFR | Purpose |
|:-----|:----|:--------|
| `docs/README.md` | NFR-14 | Project overview and quick-start |
| `docs/architecture.md` | NFR-3 | System design, data flows, container topology |
| `docs/api-guide.md` | NFR-5 | Kiwix API, ChromaDB API, Librarian tool API |
| `docs/rbac-matrix.md` | NFR-5 | Role-Based Access Control matrix |
| `docs/raci-matrix.md` | NFR-6 | Responsibility Assignment matrix |
| `docs/deployment-guide.md` | NFR-7 | Step-by-step deployment from scratch |
| `docs/maintenance-guide.md` | NFR-8 | Operational procedures, schedules, backup |
| `docs/file-manifest.md` | NFR-9 | This document — complete file inventory |
| `docs/security-gap-analysis.md` | NFR-10 | Known gaps, risk ratings, remediation plans |
| `docs/ui-guide.md` | NFR-11 | Open WebUI layout, admin setup, troubleshooting |
| `docs/security-compliance.md` | NFR-12 | FIPS/NIST/STIG/CIS/OWASP control mapping |
| `docs/user-guide.md` | NFR-13 | End-user research and edit authoring guide |
| `docs/support-tasks.md` | NFR-15 | Weekly/monthly/quarterly/annual task schedule |
| `docs/container-build-guide.md` | NFR-16 | Podman build instructions, air-gap build, security |
| `docs/bvm.md` | NFR-1 | Business Value Map and stakeholder value matrix |
| `docs/personas.md` | NFR-2 | User persona definitions (SysAdmin, AI Architect, Researcher) |

---

## 6. data/ (runtime — gitignored)

| Path | Contents |
|:-----|:---------|
| `data/zim/` | `wikipedia_en_all_maxi.zim` (~120 GB) + `.sha256` checksum |
| `data/edits/` | Researcher-authored Markdown Local Edit files |

These paths are bind-mounted into containers at runtime and are excluded from version control.

---

## 7. File Count Summary

| Category | Count |
|:---------|------:|
| Containerfiles | 4 |
| Shell scripts | 4 |
| Python files | 2 |
| Systemd units | 2 |
| Config / compose | 7 |
| CI/CD pipeline | 1 |
| Documentation (Markdown) | 16 |
| Grafana dashboard (JSON) | 1 |
| **Total tracked files** | **37** |
