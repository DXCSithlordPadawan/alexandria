# Project Alexandria — README
**Version:** 1.0.0 | **Author:** Iain Reid | **Date:** 2026-03-30
**Compliance:** FIPS 140-3 · DISA STIG · NIST SP 800-53 · CIS Level 2 · OWASP Top 10

---

## What is Project Alexandria?

Project Alexandria is a **production-grade, offline-first knowledge ecosystem** deployed on Proxmox 9.1 using rootless Podman containers. It mirrors the entirety of the English Wikipedia (~120 GB) via Kiwix and augments it with a local Markdown overlay. An AI Research Librarian (Ollama + Open WebUI) provides natural-language querying against both sources without any external network dependency.

ZIM file acquisition uses a **sneakernet protocol** as the primary and only method: an external internet-facing staging server downloads the Wikipedia ZIM archive, then transfers it to the Proxmox cluster via encrypted USB media. The Proxmox cluster never connects directly to the WAN for content downloads.

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

# 4. Import the ZIM file via sneakernet
#    On the external staging server: download ZIM and copy to FIPS 140-3 encrypted USB
#    On the Proxmox host: insert USB and run the sneakernet import script
./scripts/sneakernet.sh   # mounts USB, verifies checksum, copies ZIM

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
├── .github/
│   └── workflows/
│       └── alexandria-pipeline.yml   CI/CD pipeline (lint, build, trivy scan)
├── config/
│   ├── podman-compose.yml            Rootless Podman Compose — defines all 4 services
│   ├── systemd/                      Systemd units for sneakernet verification service
│   ├── firewall/                     Proxmox pve-firewall rules
│   ├── traefik/                      Traefik v3 static + dynamic configuration
│   ├── prometheus/                   Prometheus scrape config
│   └── grafana/                      Grafana provisioning and dashboards
├── data/                             Runtime ZIM and edit data (gitignored)
├── docs/                             Full documentation suite (16 documents)
├── scripts/                          Operational shell scripts
└── services/                         Containerfiles and Python tools for each service
```

## Documentation

| Document | Purpose |
|:---------|:--------|
| [Architecture](docs/architecture.md) | System design and data flows |
| [User Guide](docs/user-guide.md) | End-user instructions |
| [API Guide](docs/api-guide.md) | Kiwix and Librarian API reference |
| [Deployment Guide](docs/deployment-guide.md) | Step-by-step deployment |
| [Container Build Guide](docs/container-build-guide.md) | Podman build instructions |
| [Maintenance Guide](docs/maintenance-guide.md) | Operational procedures |
| [Security Compliance](docs/security-compliance.md) | Standards mapping |
| [Security Gap Analysis](docs/security-gap-analysis.md) | Known gaps and mitigations |
| [RBAC Matrix](docs/rbac-matrix.md) | Role permissions |
| [RACI Matrix](docs/raci-matrix.md) | Responsibility assignment |
| [Support Tasks](docs/support-tasks.md) | Scheduled support schedule |
| [UI Guide](docs/ui-guide.md) | Open WebUI usage |
| [BVM](docs/bvm.md) | Business Value Map |
| [Personas](docs/personas.md) | User persona definitions |
| [File Manifest](docs/file-manifest.md) | All repository files |

## Licence

Internal use — DXC Technology / Iain Reid. Not for public distribution.
