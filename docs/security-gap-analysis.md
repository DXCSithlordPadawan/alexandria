# Project Alexandria — Security Gap Analysis
**Version:** 1.0.0 | **Author:** Iain Reid | **Date:** 2026-03-30
**Standards:** FIPS 140-3 · DISA STIG · NIST SP 800-53 · CIS Level 2 · OWASP Top 10

---

## 1. Executive Summary

This document identifies known security gaps in the current v1.0.0 implementation of Project Alexandria, their risk rating, and accepted mitigations or remediation plans. It is a living document — update on every quarterly security review.

---

## 2. Gap Register

| ID | Gap Description | Standard | Risk | Status | Mitigation / Remediation |
|:---|:----------------|:---------|:----:|:------:|:--------------------------|
| GAP-001 | Container image digests not pinned (only tags used in some cases) | DISA STIG V-235800 | High | Open | Quarterly digest pin update process documented in maintenance guide. Pin to digest at next rebuild. |
| GAP-002 | No mutual TLS between internal containers | NIST SC-8 | Medium | Accepted | Containers communicate on isolated internal bridge. No external exposure. Mitigated by network isolation. Revisit if bridge is shared with other VMs. |
| GAP-003 | ChromaDB has no authentication by default | NIST AC-3 | Medium | Open | ChromaDB is on `ai-backend` bridge only — not externally reachable. Add ChromaDB token auth in Sprint 2. |
| GAP-004 | Ollama API has no authentication | NIST AC-3 | Medium | Accepted | Ollama is on `ai-backend` bridge only. Not externally reachable. Access only via WebUI. Acceptable for v1.0. |
| GAP-005 | Log aggregation not implemented | NIST AU-9 | Medium | Open | Container logs go to journald. Centralised log shipping (e.g. Loki) not yet configured. Implement in Sprint 2. |
| GAP-006 | No automated vulnerability scanning in CI | NIST SI-2 | Medium | Closed | CI/CD pipeline implemented (see `.github/workflows/alexandria-pipeline.yml`); trivy scanning integrated into build jobs for all container images. |
| GAP-007 | WebUI exposed over HTTP internally (no internal TLS) | NIST SC-8 | Low | Accepted | Mitigated by nginx reverse proxy terminating TLS externally. Internal traffic stays on loopback only. |
| GAP-008 | `ingest_edits.py` embeds without input length validation | OWASP A03 | Low | Open | Chunk size capped at 800 chars. Add explicit file size limit (e.g. 10 MB) in Sprint 2. |
| GAP-009 | No rate limiting on WebUI endpoints | OWASP A04 | Low | Open | Open WebUI does not yet have built-in rate limiting. Implement nginx rate limit in Sprint 2. |
| GAP-010 | Sneakernet USB not verified as FIPS 140-3 hardware device | NIST MP-5 | Low | Accepted | Policy control — SysAdmin is responsible for using validated media (e.g. Apricorn Aegis). Documented in sneakernet procedure. |
| GAP-011 | No IDS/IPS on internal bridges | NIST SI-3 | Low | Accepted | Scope limitation. Containers are isolated. Full IDS out of scope for v1.0. |
| GAP-012 | FIPS-validated OpenSSL not confirmed inside containers | FIPS 140-3 | High | Open | Base images (kiwix, alpine) must be verified for FIPS-validated cryptographic modules. Verify at next rebuild using `openssl version -a` inside container. |
| GAP-013 | Staging server security posture not defined | NIST AC-4, MP-5 | Medium | Open | The external internet-facing staging server is the entry point for all ZIM content. Its security requirements (hardening, access control, network exposure, audit logging) have not been formally documented. Define and document staging server security baseline in Sprint 2. |

---

## 3. Risk Scoring

| Rating | Description |
|:-------|:------------|
| **High** | Exploitable, significant data exposure or integrity impact |
| **Medium** | Exploitable under specific conditions, limited blast radius |
| **Low** | Low exploitability or mitigating controls present |

---

## 4. Sprint 2 Remediation Targets

The following gaps are targeted for Sprint 2 (next development cycle):

- GAP-003: ChromaDB authentication token
- GAP-005: Centralised log shipping to Loki or equivalent
- GAP-006: `trivy` image scanning in build pipeline
- GAP-008: File size limit in `ingest_edits.py`
- GAP-009: nginx rate limiting on WebUI

---

## 5. Review History

| Date | Reviewer | Changes |
|:-----|:---------|:--------|
| 2026-03-30 | Iain Reid | Initial gap register — v1.0.0 |
