# Project Alexandria — RBAC Matrix
**Version:** 1.0.0 | **Author:** Iain Reid | **Date:** 2026-03-30

---

## 1. Roles

| Role | Description |
|:-----|:------------|
| **SysAdmin** | Proxmox host administrator. Full infrastructure access. |
| **AI Architect** | Manages Ollama models, Open WebUI tools, ChromaDB collections. |
| **Researcher** | End user. Queries the Librarian, authors local Markdown edits. |

## 2. Permission Matrix

| Resource / Action | SysAdmin | AI Architect | Researcher |
|:-----------------|:--------:|:------------:|:----------:|
| **Proxmox host SSH** | ✅ | ❌ | ❌ |
| **Podman container management** | ✅ | Read-only | ❌ |
| **toggle_updates.sh (deprecated — manual override only)** | ✅ | ❌ | ❌ |
| **sync_wiki.sh (manual trigger)** | ✅ | ❌ | ❌ |
| **sneakernet.sh (air-gap import)** | ✅ | ❌ | ❌ |
| **verify_zim.sh** | ✅ | ✅ | ❌ |
| **Open WebUI — query Librarian** | ✅ | ✅ | ✅ |
| **Open WebUI — admin panel** | ✅ | ✅ | ❌ |
| **Ollama — model pull** | ✅ | ✅ | ❌ |
| **Ollama — model delete** | ✅ | ❌ | ❌ |
| **ChromaDB — ingest_edits.py** | ✅ | ✅ | ❌ |
| **ChromaDB — delete collection** | ✅ | ❌ | ❌ |
| **/data/edits — read** | ✅ | ✅ | ✅ |
| **/data/edits — write (new .md)** | ✅ | ✅ | ✅ |
| **/data/edits — delete** | ✅ | ❌ | ❌ |
| **/data/zim — read** | ✅ | ❌ | ❌ |
| **Firewall rule modification** | ✅ | ❌ | ❌ |
| **Security audit logs** | ✅ | Read-only | ❌ |
| **Podman secrets** | ✅ | ❌ | ❌ |

## 3. Open WebUI Role Mapping

Open WebUI has its own internal role system. Map as follows:

| Open WebUI Role | Alexandria Role |
|:----------------|:---------------|
| Admin | SysAdmin, AI Architect |
| User | Researcher |
| Pending | Not yet approved — no access |

## 4. Principle of Least Privilege

All roles are granted the minimum permissions required for their function. Elevation to SysAdmin requires membership of the `alexandria-admin` Linux group, enforced by `toggle_updates.sh`.

## 5. Role Assignment Process

New users are provisioned by SysAdmin via:
1. Linux group membership: `usermod -aG alexandria-admin <username>` (SysAdmin only)
2. Open WebUI admin panel: promote user from Pending → User or Admin
3. Document assignment in the change log
