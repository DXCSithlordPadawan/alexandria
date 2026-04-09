# Project Alexandria — Container Build Guide
**Version:** 1.0.0 | **Author:** Iain Reid | **Date:** 2026-03-30
**Runtime:** Rootless Podman on Proxmox 9.1 (Debian 13)

---

## 1. Prerequisites

```bash
# Verify rootless Podman is installed (≥ 5.0)
podman --version

# Verify podman-compose is installed
podman-compose --version

# Verify subuid/subgid mapping for the alexandria user
grep "^alexandria:" /etc/subuid /etc/subgid
# Expected: alexandria:100000:65536
```

If subuid/subgid mapping is missing:
```bash
usermod --add-subuids 100000-165535 --add-subgids 100000-165535 alexandria
podman system migrate
```

---

## 2. Directory Structure for Builds

Each service has its own build context directory under `services/`:

```
services/
├── kiwix/          Containerfile
├── updater/        Containerfile + sync_wiki.sh (COPY source)
├── chromadb/       Containerfile
├── ollama/         Containerfile
└── openwebui/      Containerfile + librarian_tool.py + ingest_edits.py
```

The `podman-compose.yml` sets `build.context` to each service directory and `build.dockerfile` to `Containerfile`.

---

## 3. Building Individual Images

All build commands run from the repository root as the `alexandria` user.

### 3.1 Kiwix

```bash
podman build \
  --tag localhost/alexandria-wiki:1.0.0 \
  --label "build-date=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  services/kiwix/
```

### 3.2 ChromaDB

```bash
podman build \
  --tag localhost/alexandria-chroma:1.0.0 \
  services/chromadb/
```

### 3.3 Ollama

```bash
podman build \
  --tag localhost/alexandria-ollama:1.0.0 \
  services/ollama/
```

### 3.4 Open WebUI

```bash
podman build \
  --tag localhost/alexandria-webui:1.0.0 \
  services/openwebui/
```

---

## 4. Building All Images via podman-compose

```bash
cd config
podman-compose --env-file .env build
```

This builds all five services in dependency order using the `build.context` definitions in `podman-compose.yml`.

---

## 5. Security Hardening During Build

The following hardening measures are applied at build time and do not require runtime flags:

| Measure | Where applied |
|:--------|:-------------|
| Non-root user created and set | All Containerfiles |
| `no-new-privileges` | Declared in podman-compose.yml |
| `cap_drop: ALL` | Declared in podman-compose.yml |
| Read-only root filesystem | Kiwix and updater containers |
| Pinned base image tags | All Containerfiles |
| Telemetry disabled | ChromaDB Containerfile (`ANONYMIZED_TELEMETRY=false`) |
| Minimal installed packages | Updater Alpine (`apk add` with explicit versions) |
| No shell in entrypoints | Entrypoints use exec array form — no `/bin/sh -c` |

---

## 6. Verifying Built Images

```bash
# List built images
podman images | grep alexandria

# Inspect a specific image for user and entrypoint
podman inspect localhost/alexandria-wiki:1.0.0 \
  --format 'User: {{.Config.User}} | Entrypoint: {{.Config.Entrypoint}}'

# Check for known CVEs with trivy (install separately)
trivy image localhost/alexandria-wiki:1.0.0
trivy image localhost/alexandria-chroma:1.0.0
```

---

## 7. Updating Pinned Versions (Quarterly)

1. Check upstream release pages for each base image:
   - Kiwix: https://github.com/kiwix/kiwix-tools/releases
   - Alpine: https://hub.docker.com/_/alpine/tags
   - ChromaDB: https://github.com/chroma-core/chroma/releases
   - Ollama: https://github.com/ollama/ollama/releases
   - Open WebUI: https://github.com/open-webui/open-webui/releases

2. Update the `FROM` line in each `Containerfile`.

3. Rebuild and test in a non-production environment.

4. Run `trivy` CVE scan on new images.

5. Commit updated Containerfiles to Git with the version bump noted in the commit message.

---

## 8. Air-Gapped Build

In fully air-gapped environments, base images must be pre-loaded from a trusted external workstation:

```bash
# On internet-facing workstation: save images to tar archives
podman pull ghcr.io/kiwix/kiwix-serve:3.7.0
podman save ghcr.io/kiwix/kiwix-serve:3.7.0 -o kiwix-serve-3.7.0.tar
# Repeat for each base image

# Copy tars to FIPS 140-3 validated USB (sneakernet protocol)

# On Proxmox host: load images from tar
podman load -i kiwix-serve-3.7.0.tar
# Repeat for each image

# Then build service images using the locally loaded base images
podman-compose --env-file .env build
```

---

## 9. Container Startup Order

The `depends_on` conditions in `podman-compose.yml` enforce this startup order:

```
chromadb (healthy) ──┐
                     ├──► openwebui (waits for all three)
ollama (healthy) ────┤
                     │
kiwix (healthy) ─────┘
```

ZIM files are imported via `sneakernet.sh` before the containers start. The `kiwix` container mounts the ZIM directory read-only and will start cleanly as long as a valid ZIM file is present.
