# PRODUCT REQUIREMENTS DOCUMENT: PROJECT ALEXANDRIA

**Project Title:** Alexandria Local (Secure Wikipedia & AI Mirror)  
**Version:** 1.0  
**Date:** 2026-03-25  
**Target Platform:** Proxmox 9.1 (Debian 13)  
**Compliance Level:** FIPS 140-3, DISA STIG, NIST SP 800-53, CIS Level 2, OWASP Top 10  
**Author:** Iain Reid (Project Architect)

---

## 1. EXECUTIVE SUMMARY
Project Alexandria establishes a production-grade, offline-first knowledge ecosystem. It mirrors the entirety of English Wikipedia using Kiwix (.zim) and augments it with a persistent, user-editable Markdown layer. The system is integrated into an AI stack (Ollama/Open WebUI) to provide a "Research Librarian" interface for high-fidelity data retrieval without external dependencies.

---

## 2. FUNCTIONAL REQUIREMENTS

### 2.1 Content & Storage
* **FR-1: Automated Mirroring:** Automated weekly synchronization of the `wikipedia_en_all_maxi.zim` archive (~120GB+).
* **FR-2: Persistence:** Local user edits stored in `/data/edits` must remain untouched during .zim update cycles.
* **FR-3: Hybrid Retrieval:** The AI must query the Kiwix API for general facts and the Local Edits folder for specialized/corrected information.
* **FR-4: Sneaker-net Protocol:** Support for manual imports via encrypted physical media for air-gapped environments.

### 2.2 AI Integration
* **FR-5: Tool-Based Search:** A Python-based "Function" within Open WebUI to bridge the LLM to the local Kiwix server.
* **FR-6: RAG Ingestion:** Vector-based indexing of the local Markdown overlay.
* **FR-7: Logic Priority:** AI responses must prioritize Local Edits over Wikipedia entries in the event of a factual conflict.
* **FR-8: Vector Database:** ChromeDB is considered the lead contender.

### 2.3 Business Value Mapping
* **NFR-1: Business Value Mapping:** A markdown document that creates a BVM for the solution.
* **NFR-2: Personas Definition:** A markdown document that creates a PERSONA Mapping for the solution.

### 2.4 Business Documentation
* **NFR-3: Architecture Document:** A markdown document that creates a BVM for the solution.
* **NFR-5: API Guide:** A markdown document that creates an API Guide for the solution.
* **NFR-5: RBAC Matrix:** A markdown document that creates a RBAC Matrix for the solution.
* **NFR-6: RACI Matrix:** A markdown document that creates a RACI Matrix for the solution.
* **NFR-7: Deployment Guide:** A markdown document that creates a Deployment Guide for the solution.
* **NFR-8: Maintenance Guide:** A markdown document that creates a Maintenance Guide for the solution.
* **NFR-9: File Manifest:** A markdown document that creates a File Manifest for the solution.
* **NFR-10: Security Gap Analysis:** A markdown document that creates a Security Gap Analysis for the solution.
* **NFR-11: User Interface Guide:** A markdown document that creates a UI Guide for the solution.
* **NFR-12: Security Compliance:** A markdown document that creates a Security Compliance against the security standards for the solution.
* **NFR-13: User Guide:** A markdown document that creates a User Guide for the solution.
* **NFR-14: README:** A markdown document that creates an overview for the solution.
* **NFR-15: Support Tasks:** A markdown document that creates an Support Task Schedule for the solution.
* **NFR-16: CONTAINER BUILD GUIDE:** A markdown document that creates an a guide for building PODMAN Containers for the solution.

---

## 3. TECHNICAL SPECIFICATIONS

### 3.1 Architecture
The system utilizes a Sidecar Pattern on a Proxmox 9.1 host using rootless Podman containers.

* **Base Layer:** Kiwix-Serve (Read-Only .zim mount).
* **Update Layer:** Alpine-based Sidecar (Weekly wget sync).
* **Intelligence Layer:** Ollama (Inference) + Open WebUI (Orchestration).

### 3.2 Podman Configuration (Hardened)
```yaml
services:
  kiwix:
    image: ghcr.io/kiwix/kiwix-serve:latest
    container_name: alexandria-wiki
    command: /data/zim/wikipedia_en_all_maxi.zim
    security_opt: [no-new-privileges]
    cap_drop: [ALL]
    volumes:
      - /mnt/pve/alexandria/zim:/data/zim:ro,Z
    networks: [internal]

  updater:
    image: alpine:latest
    container_name: alexandria-sync
    volumes:
      - /mnt/pve/alexandria/zim:/data/zim:rw,Z
    entrypoint: ["/bin/sh", "-c", "while true; do sleep 604800; wget -N -P /data/zim [https://download.kiwix.org/zim/wikipedia/wikipedia_en_all_maxi.zim](https://download.kiwix.org/zim/wikipedia/wikipedia_en_all_maxi.zim); done"]
    networks: [internal]

networks:
  internal:
    driver: bridge
```	

## 4. SECURITY & COMPLIANCE

### 4.1 Encryption & Hardening
* **FIPS 140-3:** Data at rest is protected via LUKS2/ZFS encryption using validated modules. Host kernel must have `fips=1` enabled.
* **DISA STIG:** Containers run with `no-new-privileges` and minimal capabilities. Container Platform SRG alignment required.
* **CIS Level 2:** Rootless Podman execution with unprivileged UID mapping (100000+). Hardened kernel parameters applied via `sysctl`.
* **OWASP Top 10:** Protection against A03:2021 (Injection) via strict API input validation in Open WebUI Tools.

### 4.2 Network Time-Gating
To satisfy **NIST AC-4 (Information Flow Enforcement)**, outbound WAN access is strictly gated.
* **Schedule:** Sunday 02:00 – 04:00 (Weekly Update Window).
* **Mechanism:** Systemd timers triggering `pve-firewall` Security Group toggles on the Proxmox host.
* **Manual Override:** Restricted to `SysAdmin` role via `toggle_updates.sh` script.

---

## 5. ROLES & MAINTENANCE (RACI)

| Task / Activity | SysAdmin | AI Architect | Researcher |
| :--- | :---: | :---: | :---: |
| Infrastructure Hardening | **R/A** | C | I |
| Wikipedia Sync Management| **R** | A | I |
| Local Content Authoring  | I | C | **R/A** |
| Persona/Tool Development | C | **R/A** | I |
| Security Audit & Logging | **A** | I | C |

**Legend:** **R**=Responsible, **A**=Accountable, **C**=Consulted, **I**=Informed.

---

## 6. MAINTENANCE PROCEDURES

### 6.1 Integrity & Verification
* **Weekly:** Automated `sha256sum` verification of new .zim archives post-download.
* **Monthly:** `zpool scrub` or filesystem integrity checks on the Proxmox storage pool.
* **Persona Audit:** Run `persona_test.py` to ensure LLM compliance with citation and hallucination guardrails.

### 6.2 Backup Strategy
* **Daily:** Snapshot of the `/data/edits` and `/data/config` directories via Proxmox Backup Server or local vzdump.
* **Note:** The 120GB+ `.zim` file is excluded from daily backups as it is a reproducible artifact from the Kiwix mirrors.

---

## 7. AI SYSTEM PROMPT (THE LIBRARIAN)

```text
# Role
You are the Alexandria Research Librarian. Your goal is to provide objective, 
fact-based information derived solely from the local Wikipedia mirror.

# Constraints
1. Source Primacy: Prioritize information found in the local Wikipedia 
   (Kiwix) and Local Edits.
2. Citation: Prefix information with [Wikipedia] or [Local Edit].
3. Hallucination Guard: If the local data does not contain the answer, 
   state: "The local archives do not contain information on this topic."
4. Conflict Resolution: If a Local Edit contradicts Wikipedia, the 
   Local Edit is the single source of truth.

# Structure
- Summary: 2-3 sentence overview.
- Key Facts: Bulleted list of data points.
- Cross-References: Suggest 3 related local topics.
```

## 8. SNEAKER-NET UPDATE PROTOCOL (AIR-GAP)

In environments where the Proxmox host is fully air-gapped or network-restricted:

### 1. **Staging:** On a secure, internet-facing workstation, download the latest `.zim` archive and its corresponding `.sha256` hash file from the Kiwix library.
### 2. **Verification:** Execute a checksum validation to ensure file integrity before transfer:
   ```bash
   sha256sum -c wikipedia_en_all_maxi_2026-03.zim.sha256
   ```
### 3. Encrypted Transfer: Copy the verified files to a FIPS 140-3 validated, hardware-encrypted USB drive.

### 4. Physical Import:

Insert the drive into the Proxmox host.

Identify the device (e.g., /dev/sdb1) and mount it.

Move the archive to the local ZFS/LVM storage:
```text
mount /dev/sdb1 /mnt/usb
cp /mnt/usb/*.zim /mnt/pve/alexandria/zim/
umount /mnt/usb
 ```

5. Service Refresh: Restart the Kiwix container to index the new archive:

```text
podman restart alexandria-wiki
```
 