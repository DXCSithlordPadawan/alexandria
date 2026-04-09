# Project Alexandria — RACI Matrix
**Version:** 1.0.0 | **Author:** Iain Reid | **Date:** 2026-03-30

---

## 1. Role Definitions

| Role | Description |
|:-----|:------------|
| **SysAdmin** | Proxmox host administrator. Owns infrastructure, security, and WAN gating. |
| **AI Architect** | Owns AI stack configuration, model selection, and tool development. |
| **Researcher** | End user. Authors local edits, queries the Librarian. |

**Legend:** **R** = Responsible (does the work) · **A** = Accountable (owns the outcome) · **C** = Consulted (input required) · **I** = Informed (notified of outcome)

---

## 2. RACI Table

| Task / Activity | SysAdmin | AI Architect | Researcher |
|:----------------|:--------:|:------------:|:----------:|
| **Infrastructure & Operations** | | | |
| Proxmox host provisioning and hardening | **R/A** | C | I |
| Podman container build and deployment | **R/A** | C | I |
| Firewall rule management (WAN gate) | **R/A** | I | I |
| Systemd timer configuration | **R/A** | C | I |
| Storage pool provisioning (LUKS2/ZFS) | **R/A** | I | I |
| SSL/TLS reverse proxy configuration | **R/A** | C | I |
| **Content & Synchronisation** | | | |
| Wikipedia ZIM sync management | **R** | A | I |
| ZIM integrity verification (weekly) | **R** | A | I |
| Sneakernet (air-gap import) | **R/A** | C | I |
| Local Markdown edit authoring | I | C | **R/A** |
| ChromaDB ingest trigger after new edits | **R** | **R** | I |
| **AI Stack** | | | |
| Ollama model selection and pull | C | **R/A** | I |
| Open WebUI configuration | **R** | **R/A** | I |
| Librarian system prompt development | C | **R/A** | C |
| Librarian tool (librarian_tool.py) dev | C | **R/A** | I |
| RAG ingestor (ingest_edits.py) dev | C | **R/A** | I |
| Persona/hallucination testing | C | **R/A** | C |
| **Security & Compliance** | | | |
| Security audit and logging review | **R/A** | I | C |
| Podman secret rotation | **R/A** | I | I |
| Dependency version updates | **R** | **R** | I |
| Security gap analysis | **R/A** | C | I |
| Incident response | **R/A** | C | I |
| **Documentation** | | | |
| Architecture documentation | **R** | **R/A** | I |
| User guide | I | **R/A** | C |
| RBAC / RACI maintenance | **R/A** | C | I |
| Deployment guide | **R/A** | C | I |
| Change log maintenance | **R** | **R** | I |

---

## 3. Escalation Path

1. Researcher raises issue → AI Architect
2. AI Architect cannot resolve → SysAdmin
3. SysAdmin escalates security incidents to designated ISSO within 1 hour
