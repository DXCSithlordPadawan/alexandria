# Project Alexandria — README
**Version:** 1.0.0 | **Author:** Iain Reid | **Date:** 2026-03-30
**Compliance:** FIPS 140-3 · DISA STIG · NIST SP 800-53 · CIS Level 2 · OWASP Top 10

---

## What is Project Alexandria?

Project Alexandria is a **production-grade, offline-first knowledge ecosystem** deployed on Proxmox 9.1 using rootless Podman containers. It mirrors the entirety of the English Wikipedia (~120 GB) via Kiwix and augments it with a local Markdown overlay. An AI Research Librarian (Ollama + Open WebUI) provides natural-language querying against both sources without any external network dependency.

## Quick Start

```bash
# 1. Clone the repository
git clone https://your-git-host/alexandria.git /opt/alexandria
cd /opt/alexandria

# 2. Configure environment
cp config/.env.example config/.env
# Edit config/.env with your site-specific values

# 3. Create the Podman secret
printf 'YOUR_SECRET_KEY' | podman secret create webui_secret_key -

# 4. First ZIM download (requires WAN gate open — see deployment guide)
./scripts/toggle_updates.sh open
./scripts/sync_wiki.sh &    # runs in background; 120 GB download
# Once complete:
./scripts/toggle_updates.sh close

# 5. Start all services
cd config && podman-compose --env-file .env up -d

# 6. Pull the LLM model (first run only)
podman exec alexandria-ollama ollama pull llama3.2

# 7. Ingest local edits into ChromaDB
podman exec alexandria-webui python /app/backend/tools/ingest_edits.py
```

The WebUI is available at `http://localhost:3000` (localhost only — expose via reverse proxy with TLS for remote access).

## Repository Layout

```
alexandria/
├── config/         Podman Compose, systemd units, firewall rules
├── data/           Runtime ZIM and edit data (gitignored)
├── docs/           Full documentation suite (16 documents)
├── scripts/        Operational shell scripts
└── services/       Containerfiles and Python tools for each service
```

## Documentation

| Document | Purpose |
|:---------|:--------|
| [Architecture](architecture.md) | System design and data flows |
| [User Guide](user-guide.md) | End-user instructions |
| [API Guide](api-guide.md) | Kiwix and Librarian API reference |
| [Deployment Guide](deployment-guide.md) | Step-by-step deployment |
| [Container Build Guide](container-build-guide.md) | Podman build instructions |
| [Maintenance Guide](maintenance-guide.md) | Operational procedures |
| [Security Compliance](security-compliance.md) | Standards mapping |
| [Security Gap Analysis](security-gap-analysis.md) | Known gaps and mitigations |
| [RBAC Matrix](rbac-matrix.md) | Role permissions |
| [RACI Matrix](raci-matrix.md) | Responsibility assignment |
| [Support Tasks](support-tasks.md) | Scheduled support schedule |
| [UI Guide](ui-guide.md) | Open WebUI usage |
| [BVM](bvm.md) | Business Value Map |
| [Personas](personas.md) | User persona definitions |
| [File Manifest](file-manifest.md) | All repository files |

## Licence

Internal use — DXC Technology / Iain Reid. Not for public distribution.
