# Project Alexandria — Security Compliance Document
**Version:** 1.0.0 | **Author:** Iain Reid | **Date:** 2026-03-30

---

## 1. Standards Coverage

| Standard | Version / Edition | Applicability |
|:---------|:-----------------|:--------------|
| FIPS 140-3 | 2019 | Cryptographic modules, storage encryption |
| NIST SP 800-53 | Rev 5 | Security control baseline |
| DISA STIG | Container Platform SRG v2r2 | Container hardening |
| CIS Benchmark | Level 2 — Linux + Docker/Podman | Host and runtime |
| OWASP Top 10 | 2021 | Application security |

---

## 2. NIST SP 800-53 Rev 5 Control Mapping

| Control ID | Control Name | Implementation |
|:-----------|:-------------|:---------------|
| AC-2 | Account Management | Linux accounts via `useradd`; Open WebUI user management; `alexandria-admin` group |
| AC-3 | Access Enforcement | RBAC matrix enforced at OS and WebUI level |
| AC-4 | Information Flow Enforcement | `internal: true` Podman networks; WAN gate via pve-firewall; Sunday 02:00 window only |
| AC-6 | Least Privilege | All containers: `cap_drop: ALL`; rootless Podman; no-new-privileges |
| AU-2 | Event Logging | journald for all systemd services; container logs; WAN gate audit log |
| AU-9 | Protection of Audit Information | Log files owner `root:alexandria`, mode `640`; journald with `ForwardToSyslog` |
| CM-6 | Configuration Settings | CIS Level 2 sysctl applied; Containerfiles version-pinned |
| CM-7 | Least Functionality | Containers run single process; all unused caps dropped; read-only root FS |
| IA-5 | Authenticator Management | Podman secret for WebUI key; no plaintext secrets in files |
| MP-5 | Media Transport | Sneakernet protocol with FIPS 140-3 validated hardware-encrypted USB; sha256 verification |
| SC-8 | Transmission Confidentiality | TLS 1.3 on nginx reverse proxy; internal traffic on isolated bridge |
| SC-28 | Protection of Information at Rest | LUKS2 encryption on Proxmox storage pool; FIPS-validated modules required |
| SI-2 | Flaw Remediation | Pinned image versions; quarterly rebuild with updated pins |
| SI-7 | Software Integrity | sha256sum on every ZIM download; atomic file replacement |
| SI-10 | Information Input Validation | `_sanitise_query()` regex in librarian_tool.py; path traversal check in ingest_edits.py |
| SI-12 | Information Management | Telemetry disabled in ChromaDB; no data sent externally |

---

## 3. FIPS 140-3 Compliance

| Requirement | Implementation | Status |
|:------------|:--------------|:------:|
| Host kernel FIPS mode | `fips=1` in `/proc/cmdline` | Required pre-deploy |
| Storage encryption | LUKS2 with AES-256-XTS (FIPS-validated) | Required pre-deploy |
| TLS cipher suites | TLS 1.3 only; `TLS_AES_256_GCM_SHA384`, `TLS_CHACHA20_POLY1305_SHA256` | ✅ In nginx config |
| Container cryptographic modules | Must verify FIPS-validated OpenSSL inside images | ⚠️ GAP-012 — open |
| FIPS-validated USB media | Apricorn Aegis or equivalent for sneakernet | Policy control |

---

## 4. DISA STIG Container Platform SRG Alignment

| STIG ID | Requirement | Implementation |
|:--------|:------------|:--------------|
| V-235800 | Images must be from trusted registries and pinned | Pinned tags in all Containerfiles; digest update process documented |
| V-235801 | Containers must not run as root | All containers use non-root users (kiwix, syncer, chroma users) |
| V-235802 | Containers must drop all capabilities | `cap_drop: [ALL]` in all service definitions |
| V-235803 | No-new-privileges must be enforced | `security_opt: [no-new-privileges:true]` on all containers |
| V-235804 | Container file systems must be read-only where possible | `read_only: true` on kiwix and updater |
| V-235805 | Resource limits must be defined | `mem_limit` and `cpus` set on all containers |
| V-235806 | Secrets must not be in environment variables | `podman secret` used for `WEBUI_SECRET_KEY` |

---

## 5. CIS Level 2 — Rootless Podman

| CIS Control | Requirement | Implementation |
|:------------|:------------|:--------------|
| 5.1 | Rootless execution | `alexandria` system user with UID mapping 100000+ |
| 5.2 | Unprivileged port binding | WebUI binds on 8080 (unprivileged); nginx on 443 on host |
| 5.3 | No privileged containers | No `--privileged` flag used anywhere |
| 5.4 | Network namespace isolation | Separate `internal` and `ai-backend` bridge networks |
| 5.5 | No host PID/IPC namespace | Not shared in any container definition |

---

## 6. OWASP Top 10 (2021) Mapping

| OWASP ID | Risk | Mitigation |
|:---------|:-----|:-----------|
| A01: Broken Access Control | RBAC enforced at OS and WebUI level; `alexandria-admin` group check in toggle script | ✅ |
| A02: Cryptographic Failures | LUKS2 at rest; TLS 1.3 in transit; no weak ciphers | ✅ |
| A03: Injection | `_sanitise_query()` regex; parameterised ChromaDB queries; no shell interpolation in scripts | ✅ |
| A04: Insecure Design | Least privilege by design; air-gap capable; WAN gating | ✅ |
| A05: Security Misconfiguration | Pinned images; read-only FS; all caps dropped; no default credentials | ✅ |
| A06: Vulnerable Components | Pinned dependencies; quarterly rebuild cycle | ⚠️ No automated CVE scan (GAP-006) |
| A07: Auth/Identification Failures | Podman secret; WebUI auth required; no anonymous access | ✅ |
| A08: Integrity Failures | sha256 on every ZIM; atomic file replace; Git for config | ✅ |
| A09: Logging Failures | journald + WAN gate audit log | ⚠️ No centralised SIEM (GAP-005) |
| A10: SSRF | Librarian tool queries only `kiwix` and `chromadb` hostnames (internal only) | ✅ |

---

## 7. Review Schedule

This document must be reviewed and updated:
- After every quarterly container rebuild
- After any security incident
- When a new standard revision is published
- At minimum annually

| Date | Reviewer | Version |
|:-----|:---------|:--------|
| 2026-03-30 | Iain Reid | 1.0.0 |
