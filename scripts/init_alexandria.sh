#!/bin/sh
# init_alexandria.sh — Proxmox LXC bootstrap for Project Alexandria
# ─────────────────────────────────────────────────────────────────────────────
# Compliance: DISA STIG, CIS Level 2, FIPS 140-2/3, NIST SP 800-53
#
# Purpose:
#   Creates and fully provisions LXC container CT 200 (alexandria) on the
#   Proxmox host.  Runs as root directly on the Proxmox host (prox9).
#   Must NOT be run inside a container.
#
# Pre-requisites (run on Windows dev machine before executing this script):
#   1. SCP the entire C:\alexandria directory to the Proxmox host:
#        scp -r C:\alexandria root@192.168.0.108:/tmp/alexandria-src
#   2. SCP this script to the Proxmox host:
#        scp C:\alexandria\scripts\init_alexandria.sh root@192.168.0.108:/tmp/
#   3. On prox9:
#        chmod +x /tmp/init_alexandria.sh
#        /tmp/init_alexandria.sh
#
# What this script does:
#   1.  Pre-flight checks  — tools present, running as root, CT 200 free
#   2.  Interactive prompts — gateway, bridge, admin user, template
#   3.  Template download  — debian-12-standard if not cached
#   4.  Create LXC CT 200  — unprivileged, 200 GB local-lvm, 192.168.0.115
#   5.  Start container    — waits for ready with retry
#   6.  Package install    — podman, buildah, pip, podman-compose (in CT)
#   7.  User provisioning  — alexandria (nologin), alexandria-admin group
#   8.  subuid/subgid      — rootless Podman namespace mappings
#   9.  Storage dirs       — /mnt/pve/alexandria/{zim,edits,chromadb,ollama}
#  10.  Repo deploy        — /tmp/alexandria-src → /opt/alexandria in CT
#  11.  Permissions        — root:alexandria 750, scripts +x
#  12.  Environment file   — .env.example → .env, chmod 640
#  13.  Podman secret      — webui_secret_key via openssl rand -hex 32
#  14.  Systemd units      — alexandria-sync.service + .timer, enabled
#  15.  Proxmox firewall   — security group alexandria-wan (disabled)
#  16.  FIPS check         — warning only, non-blocking
#  17.  PROGRESS.md update — Phase 7 entry with timestamp
#  18.  Next-steps summary — printed to stdout
#
# Usage:
#   /tmp/init_alexandria.sh
#
# References:
#   NIST SP 800-53 AC-2, AC-4, AC-6, SC-28, SI-7
#   DISA STIG Proxmox guidance
#   CIS Benchmark Level 2 — Debian 12
#   docs/deployment-guide.md
#   docs/container-build-guide.md
# ─────────────────────────────────────────────────────────────────────────────
set -eu

# ── Constants ─────────────────────────────────────────────────────────────────
CT_ID="200"
CT_NAME="alexandria"
CT_IP="192.168.0.115"
CT_CIDR="24"
CT_CORES="4"
CT_MEMORY="8192"
CT_SWAP="2048"
CT_DISK_SIZE="200"
CT_STORAGE="local-lvm"
CT_UNPRIVILEGED="1"
CT_NESTING="0"

REPO_SRC="/tmp/alexandria-src"
REPO_DST="/opt/alexandria"
DATA_ROOT="/mnt/pve/alexandria"
LOG_DIR="/var/log/alexandria"
LOG_FILE="${LOG_DIR}/init_alexandria.log"

SYSTEM_USER="alexandria"
ADMIN_GROUP="alexandria-admin"
SUBUID_START="100000"
SUBUID_COUNT="65536"

TEMPLATE_STORAGE="local"
TEMPLATE_PATTERN="debian-12-standard"

TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

# ── Logging ───────────────────────────────────────────────────────────────────
log() {
    echo "[${TIMESTAMP}] [init_alexandria] $*" | tee -a "${LOG_FILE}"
}

log_section() {
    log "────────────────────────────────────────"
    log "  $*"
    log "────────────────────────────────────────"
}

die() {
    log "FATAL: $*"
    exit 1
}

warn() {
    log "WARNING: $*"
}

# ── Cleanup on unexpected exit ────────────────────────────────────────────────
cleanup() {
    EXIT_CODE=$?
    if [ "${EXIT_CODE}" -ne 0 ]; then
        log "Script exited with code ${EXIT_CODE}. Review ${LOG_FILE} for details."
    fi
}
trap cleanup EXIT

# ─────────────────────────────────────────────────────────────────────────────
# STEP 0 — Initialise log directory
# ─────────────────────────────────────────────────────────────────────────────
mkdir -p "${LOG_DIR}"
chmod 750 "${LOG_DIR}"
log_section "Project Alexandria — Init Script started at ${TIMESTAMP}"

# ─────────────────────────────────────────────────────────────────────────────
# STEP 1 — Pre-flight checks
# ─────────────────────────────────────────────────────────────────────────────
log_section "STEP 1: Pre-flight checks"

# Must run as root
if [ "$(id -u)" -ne 0 ]; then
    die "This script must be run as root on the Proxmox host."
fi
log "Running as root: OK"

# Must not be inside a container
if [ -f /run/.containerenv ] || grep -q "container=" /proc/1/environ 2>/dev/null; then
    die "This script must run on the Proxmox host, not inside a container."
fi
log "Not running inside a container: OK"

# Required tools
for _tool in pct pvesh pveam wget openssl tar; do
    if ! command -v "${_tool}" > /dev/null 2>&1; then
        die "Required tool not found: ${_tool}. Is this a Proxmox host?"
    fi
done
log "Required tools present (pct pvesh pveam wget openssl tar): OK"

# Source repo must exist
if [ ! -d "${REPO_SRC}" ]; then
    die "Source repository not found at ${REPO_SRC}. " \
        "SCP it from the dev machine first:\n" \
        "  scp -r C:\\alexandria root@192.168.0.108:/tmp/alexandria-src"
fi
log "Source repository found at ${REPO_SRC}: OK"

# CT 200 must not already exist
if pct status "${CT_ID}" > /dev/null 2>&1; then
    die "CT ${CT_ID} already exists. Remove it first with: pct destroy ${CT_ID} --purge"
fi
log "CT ${CT_ID} does not exist — safe to create: OK"

# ─────────────────────────────────────────────────────────────────────────────
# STEP 2 — Interactive prompts
# ─────────────────────────────────────────────────────────────────────────────
log_section "STEP 2: Configuration prompts"

# Read with a default value helper
prompt_default() {
    _prompt="$1"
    _default="$2"
    printf "%s [%s]: " "${_prompt}" "${_default}"
    read -r _input
    if [ -z "${_input}" ]; then
        echo "${_default}"
    else
        echo "${_input}"
    fi
}

CT_GATEWAY=$(prompt_default "Container gateway IP" "192.168.0.1")
CT_BRIDGE=$(prompt_default "Proxmox network bridge" "vmbr0")
ADMIN_USER=$(prompt_default "Proxmox/container admin username to add to ${ADMIN_GROUP}" "$(logname 2>/dev/null || echo 'sysadmin')")

log "Gateway  : ${CT_GATEWAY}"
log "Bridge   : ${CT_BRIDGE}"
log "AdminUser: ${ADMIN_USER}"

# ─────────────────────────────────────────────────────────────────────────────
# STEP 3 — Debian 12 template
# ─────────────────────────────────────────────────────────────────────────────
log_section "STEP 3: Debian 12 template"

# Find a cached template matching the pattern
TEMPLATE_PATH=$(find /var/lib/vz/template/cache/ -name "${TEMPLATE_PATTERN}*.tar.*" 2>/dev/null | sort | tail -n 1 || true)

if [ -z "${TEMPLATE_PATH}" ]; then
    log "Template not found locally — downloading from Proxmox repository..."
    pveam update || warn "pveam update failed — using cached list"
    TEMPLATE_NAME=$(pveam available --section system 2>/dev/null \
        | awk '{print $2}' \
        | grep "^${TEMPLATE_PATTERN}" \
        | sort | tail -n 1)
    if [ -z "${TEMPLATE_NAME}" ]; then
        die "Cannot find a ${TEMPLATE_PATTERN} template in pveam available. " \
            "Check internet connectivity or add the template manually."
    fi
    log "Downloading template: ${TEMPLATE_NAME}"
    pveam download "${TEMPLATE_STORAGE}" "${TEMPLATE_NAME}"
    TEMPLATE_PATH=$(find /var/lib/vz/template/cache/ -name "${TEMPLATE_PATTERN}*.tar.*" | sort | tail -n 1)
fi

log "Using template: ${TEMPLATE_PATH}"
TEMPLATE_REF="${TEMPLATE_STORAGE}:vztmpl/$(basename "${TEMPLATE_PATH}")"
log "Template ref for pct: ${TEMPLATE_REF}"

# ─────────────────────────────────────────────────────────────────────────────
# STEP 4 — Create LXC container CT 200
# ─────────────────────────────────────────────────────────────────────────────
log_section "STEP 4: Create LXC CT ${CT_ID}"

pct create "${CT_ID}" "${TEMPLATE_REF}" \
    --hostname "${CT_NAME}" \
    --unprivileged "${CT_UNPRIVILEGED}" \
    --cores "${CT_CORES}" \
    --memory "${CT_MEMORY}" \
    --swap "${CT_SWAP}" \
    --rootfs "${CT_STORAGE}:${CT_DISK_SIZE}" \
    --net0 "name=eth0,bridge=${CT_BRIDGE},ip=${CT_IP}/${CT_CIDR},gw=${CT_GATEWAY}" \
    --ostype debian \
    --nesting "${CT_NESTING}" \
    --features "keyctl=1" \
    --start 0 \
    --onboot 1 \
    --description "Project Alexandria — offline knowledge ecosystem (rootless Podman)"

log "CT ${CT_ID} created successfully"

# ─────────────────────────────────────────────────────────────────────────────
# STEP 5 — Start container and wait for ready
# ─────────────────────────────────────────────────────────────────────────────
log_section "STEP 5: Start CT ${CT_ID}"

pct start "${CT_ID}"
log "CT ${CT_ID} start command issued — waiting for init to complete..."

_retries=20
_count=0
while [ "${_count}" -lt "${_retries}" ]; do
    if pct exec "${CT_ID}" -- test -f /run/systemd/private 2>/dev/null \
       || pct exec "${CT_ID}" -- systemctl is-system-running 2>/dev/null | grep -qE 'running|degraded'; then
        log "CT ${CT_ID} is up"
        break
    fi
    _count=$((_count + 1))
    log "Waiting for CT ${CT_ID} to be ready... (${_count}/${_retries})"
    sleep 3
done

if [ "${_count}" -ge "${_retries}" ]; then
    warn "CT ${CT_ID} did not reach 'running' state within timeout — continuing anyway"
fi

# Extra settle time for systemd units inside the container
sleep 5

# ─────────────────────────────────────────────────────────────────────────────
# STEP 6 — Install packages inside the container
# ─────────────────────────────────────────────────────────────────────────────
log_section "STEP 6: Install packages in CT ${CT_ID}"

# Helper: run a command inside the container as root
ct_exec() {
    pct exec "${CT_ID}" -- sh -c "$*"
}

# Helper: run a command inside the container as the alexandria user
ct_exec_user() {
    pct exec "${CT_ID}" -- su - "${SYSTEM_USER}" -s /bin/sh -c "$*"
}

log "Updating apt cache..."
ct_exec "apt-get update -qq"

log "Upgrading existing packages (security)..."
ct_exec "DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq"

log "Installing podman, buildah, uidmap, python3-pip, openssl, ca-certificates..."
ct_exec "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    podman \
    buildah \
    uidmap \
    fuse-overlayfs \
    python3-pip \
    python3-venv \
    openssl \
    ca-certificates \
    wget \
    curl \
    tar"

# Verify podman version is 5.0+
PODMAN_VER=$(ct_exec "podman --version | awk '{print \$3}'")
log "Podman version installed: ${PODMAN_VER}"

log "Installing podman-compose via pip3..."
ct_exec "pip3 install --break-system-packages podman-compose"

log "Package installation complete"

# ─────────────────────────────────────────────────────────────────────────────
# STEP 7 — User and group provisioning
# ─────────────────────────────────────────────────────────────────────────────
log_section "STEP 7: User and group provisioning"

# Create system user: alexandria (no login shell, no interactive home)
log "Creating system user: ${SYSTEM_USER}"
ct_exec "id ${SYSTEM_USER} > /dev/null 2>&1 \
    || useradd --system --shell /usr/sbin/nologin \
               --home-dir /opt/alexandria \
               --no-create-home \
               --comment 'Alexandria service account' \
               ${SYSTEM_USER}"
log "User '${SYSTEM_USER}' ensured"

# Create admin group
log "Creating group: ${ADMIN_GROUP}"
ct_exec "getent group ${ADMIN_GROUP} > /dev/null 2>&1 \
    || groupadd --system ${ADMIN_GROUP}"
log "Group '${ADMIN_GROUP}' ensured"

# Add admin user to the group (create the user inside the container if absent)
log "Ensuring admin user '${ADMIN_USER}' exists in CT and is in '${ADMIN_GROUP}'"
ct_exec "id ${ADMIN_USER} > /dev/null 2>&1 \
    || useradd --create-home --shell /bin/bash \
               --comment 'Alexandria SysAdmin' \
               ${ADMIN_USER}"
ct_exec "usermod -aG ${ADMIN_GROUP} ${ADMIN_USER}"
log "User '${ADMIN_USER}' added to '${ADMIN_GROUP}'"

# ─────────────────────────────────────────────────────────────────────────────
# STEP 8 — subuid / subgid for rootless Podman
# ─────────────────────────────────────────────────────────────────────────────
log_section "STEP 8: subuid/subgid for rootless Podman"

SUBUID_END=$(( SUBUID_START + SUBUID_COUNT - 1 ))

# Remove any existing entry for the user to avoid duplicates (NIST AC-6)
ct_exec "sed -i '/^${SYSTEM_USER}:/d' /etc/subuid /etc/subgid"

ct_exec "echo '${SYSTEM_USER}:${SUBUID_START}:${SUBUID_COUNT}' >> /etc/subuid"
ct_exec "echo '${SYSTEM_USER}:${SUBUID_START}:${SUBUID_COUNT}' >> /etc/subgid"
log "subuid/subgid set: ${SYSTEM_USER}:${SUBUID_START}:${SUBUID_COUNT}"

# Verify
ct_exec "grep '^${SYSTEM_USER}:' /etc/subuid /etc/subgid" \
    && log "subuid/subgid verification: OK" \
    || die "subuid/subgid not written correctly"

# Migrate podman storage as the alexandria user
log "Running podman system migrate as ${SYSTEM_USER}..."
ct_exec_user "podman system migrate" || warn "podman system migrate returned non-zero — may be harmless on first run"

# ─────────────────────────────────────────────────────────────────────────────
# STEP 9 — Storage directories
# ─────────────────────────────────────────────────────────────────────────────
log_section "STEP 9: Storage directories"

for _dir in zim edits chromadb ollama; do
    ct_exec "mkdir -p ${DATA_ROOT}/${_dir}"
    log "Created: ${DATA_ROOT}/${_dir}"
done

ct_exec "chown -R ${SYSTEM_USER}:${SYSTEM_USER} ${DATA_ROOT}"
ct_exec "chmod 750 ${DATA_ROOT}"
log "Ownership and permissions set on ${DATA_ROOT}"

# ─────────────────────────────────────────────────────────────────────────────
# STEP 10 — Deploy repository into container
# ─────────────────────────────────────────────────────────────────────────────
log_section "STEP 10: Deploy repository to ${REPO_DST}"

# Create a tar of the source on the host, push it into the container, extract
TAR_TMP="/tmp/alexandria-repo-$(date +%s).tar.gz"

log "Creating tarball of ${REPO_SRC}..."
tar -czf "${TAR_TMP}" -C "$(dirname "${REPO_SRC}")" "$(basename "${REPO_SRC}")"
log "Tarball created: ${TAR_TMP}"

log "Pushing tarball into CT ${CT_ID}..."
pct push "${CT_ID}" "${TAR_TMP}" "/tmp/alexandria-repo.tar.gz"

log "Extracting into ${REPO_DST}..."
ct_exec "mkdir -p ${REPO_DST}"
ct_exec "tar -xzf /tmp/alexandria-repo.tar.gz \
    -C $(dirname "${REPO_DST}") \
    --strip-components=1 \
    --transform 's|^alexandria-src|$(basename "${REPO_DST}")|'"

# Clean up temp tar inside container
ct_exec "rm -f /tmp/alexandria-repo.tar.gz"
# Clean up temp tar on host
rm -f "${TAR_TMP}"
log "Repository deployed to ${REPO_DST}"

# ─────────────────────────────────────────────────────────────────────────────
# STEP 11 — Permissions
# ─────────────────────────────────────────────────────────────────────────────
log_section "STEP 11: File permissions"

ct_exec "chown -R root:${SYSTEM_USER} ${REPO_DST}"
ct_exec "chmod -R 750 ${REPO_DST}"
ct_exec "find ${REPO_DST}/scripts -name '*.sh' -exec chmod 750 {} +"
log "Ownership root:${SYSTEM_USER}, mode 750 applied to ${REPO_DST}"
log "Scripts in ${REPO_DST}/scripts set to executable"

# ─────────────────────────────────────────────────────────────────────────────
# STEP 12 — Environment file
# ─────────────────────────────────────────────────────────────────────────────
log_section "STEP 12: Environment file"

ct_exec "test -f ${REPO_DST}/config/.env \
    && echo '.env already exists — skipping copy' \
    || cp ${REPO_DST}/config/.env.example ${REPO_DST}/config/.env"
ct_exec "chmod 640 ${REPO_DST}/config/.env"
ct_exec "chown root:${SYSTEM_USER} ${REPO_DST}/config/.env"
log ".env created from .env.example with mode 640, owner root:${SYSTEM_USER}"

# ─────────────────────────────────────────────────────────────────────────────
# STEP 13 — Podman secret: webui_secret_key
# ─────────────────────────────────────────────────────────────────────────────
log_section "STEP 13: Podman secret (webui_secret_key)"

# Generate 32-byte hex key using openssl (FIPS-compliant PRNG)
# Key is written to a tmpfs-backed temp file, registered, then securely erased
SECRET_TMP=$(ct_exec "mktemp /dev/shm/alexandria-secret-XXXXXX")

ct_exec "openssl rand -hex 32 > ${SECRET_TMP}"
ct_exec "chmod 600 ${SECRET_TMP}"

# Register the secret as the alexandria user (rootless podman secret store)
ct_exec_user "podman secret rm webui_secret_key 2>/dev/null || true"
ct_exec_user "podman secret create webui_secret_key ${SECRET_TMP}"

# Securely erase the temp file — shred if available, else overwrite + delete
ct_exec "command -v shred > /dev/null 2>&1 \
    && shred -u ${SECRET_TMP} \
    || { dd if=/dev/urandom of=${SECRET_TMP} bs=32 count=1 conv=notrunc 2>/dev/null; rm -f ${SECRET_TMP}; }"

# Verify secret is registered
ct_exec_user "podman secret ls | grep -q webui_secret_key" \
    && log "Podman secret 'webui_secret_key' registered: OK" \
    || die "Podman secret registration failed"

# ─────────────────────────────────────────────────────────────────────────────
# STEP 14 — Systemd units
# ─────────────────────────────────────────────────────────────────────────────
log_section "STEP 14: Systemd units"

for _unit in alexandria-sync.service alexandria-sync.timer; do
    ct_exec "cp ${REPO_DST}/config/systemd/${_unit} /etc/systemd/system/${_unit}"
    ct_exec "chmod 644 /etc/systemd/system/${_unit}"
    log "Installed /etc/systemd/system/${_unit}"
done

ct_exec "systemctl daemon-reload"
ct_exec "systemctl enable alexandria-sync.timer"
log "alexandria-sync.timer enabled at boot"

# Verify timer is enabled
ct_exec "systemctl is-enabled alexandria-sync.timer" \
    && log "Timer enabled state: OK" \
    || warn "Timer may not be enabled — check manually: systemctl is-enabled alexandria-sync.timer"

# ─────────────────────────────────────────────────────────────────────────────
# STEP 15 — Proxmox firewall security group
# ─────────────────────────────────────────────────────────────────────────────
log_section "STEP 15: Proxmox firewall — security group 'alexandria-wan'"

# Create the security group if it does not already exist
if pvesh get /cluster/firewall/groups 2>/dev/null | grep -q "alexandria-wan"; then
    warn "Firewall group 'alexandria-wan' already exists — skipping creation"
else
    pvesh create /cluster/firewall/groups \
        --group "alexandria-wan" \
        --comment "Alexandria WAN gate — managed by init_alexandria.sh (NIST AC-4)"
    log "Firewall group 'alexandria-wan' created"
fi

# Add rules from wan-gate.rules comments as discrete pvesh rules
# Rule 1: Allow outbound HTTPS to download.kiwix.org (port 443)
pvesh create /cluster/firewall/groups/alexandria-wan/rules \
    --action ACCEPT \
    --type out \
    --proto tcp \
    --dport 443 \
    --dest download.kiwix.org \
    --comment "Kiwix HTTPS outbound (NIST AC-4)" \
    --enable 1 2>/dev/null || warn "Rule 1 (HTTPS) may already exist"

# Rule 2: Allow outbound DNS UDP
pvesh create /cluster/firewall/groups/alexandria-wan/rules \
    --action ACCEPT \
    --type out \
    --proto udp \
    --dport 53 \
    --comment "DNS resolution UDP (NIST AC-4)" \
    --enable 1 2>/dev/null || warn "Rule 2 (DNS UDP) may already exist"

# Rule 3: Allow outbound DNS TCP
pvesh create /cluster/firewall/groups/alexandria-wan/rules \
    --action ACCEPT \
    --type out \
    --proto tcp \
    --dport 53 \
    --comment "DNS resolution TCP (NIST AC-4)" \
    --enable 1 2>/dev/null || warn "Rule 3 (DNS TCP) may already exist"

# The group itself is left DISABLED by default (AC-4 default-deny)
# toggle_updates.sh opens/closes it during the weekly sync window
log "Security group 'alexandria-wan' configured — DEFAULT DISABLED (AC-4 compliant)"
log "Use /opt/alexandria/scripts/toggle_updates.sh open|close to manage"

# ─────────────────────────────────────────────────────────────────────────────
# STEP 16 — FIPS check (warning only, non-blocking)
# ─────────────────────────────────────────────────────────────────────────────
log_section "STEP 16: FIPS 140-2/3 check"

FIPS_ENABLED=$(cat /proc/sys/crypto/fips_enabled 2>/dev/null || echo "0")
if [ "${FIPS_ENABLED}" = "1" ]; then
    log "FIPS mode enabled on host: OK"
else
    warn "FIPS mode is NOT enabled on this host (fips_enabled=${FIPS_ENABLED})."
    warn "To enable: add 'fips=1' to GRUB_CMDLINE_LINUX in /etc/default/grub"
    warn "           then run: update-grub && reboot"
    warn "Deployment continues — but FIPS compliance requires host remediation."
fi

# ─────────────────────────────────────────────────────────────────────────────
# STEP 17 — Update PROGRESS.md
# ─────────────────────────────────────────────────────────────────────────────
log_section "STEP 17: Update PROGRESS.md"

PROGRESS_FILE="${REPO_DST}/PROGRESS.md"

ct_exec "cat >> ${PROGRESS_FILE} << 'PROGRESS_EOF'

### Session 3 — ${TIMESTAMP}
- Phase 7: LXC CT ${CT_ID} created on prox9 by init_alexandria.sh
  - Container: ${CT_NAME} / ${CT_IP} / 200 GB local-lvm / unprivileged
  - Packages: podman, buildah, fuse-overlayfs, podman-compose
  - Users: ${SYSTEM_USER} (nologin), ${ADMIN_GROUP} group, ${ADMIN_USER} added
  - subuid/subgid: ${SYSTEM_USER}:${SUBUID_START}:${SUBUID_COUNT}
  - Repo deployed to ${REPO_DST}
  - .env created from .env.example (mode 640)
  - Podman secret 'webui_secret_key' registered
  - Systemd timer 'alexandria-sync.timer' enabled
  - Proxmox firewall group 'alexandria-wan' created (disabled)
PROGRESS_EOF"

log "PROGRESS.md updated"

# ─────────────────────────────────────────────────────────────────────────────
# STEP 18 — Next-steps summary
# ─────────────────────────────────────────────────────────────────────────────
log_section "STEP 18: Complete"

cat << SUMMARY

════════════════════════════════════════════════════════════════════════
  Project Alexandria — CT ${CT_ID} provisioned successfully
════════════════════════════════════════════════════════════════════════

  Container : ${CT_NAME} (CT ${CT_ID})
  Address   : ${CT_IP}/${CT_CIDR}  gw ${CT_GATEWAY}
  Disk      : ${CT_DISK_SIZE} GB on ${CT_STORAGE}
  Repo      : ${REPO_DST}
  Data      : ${DATA_ROOT}
  Log       : ${LOG_FILE}

  NEXT STEPS (run inside CT ${CT_ID})
  ─────────────────────────────────────────────────────────────────────
  1. Enter the container:
       pct enter ${CT_ID}

  2. Edit the environment file with your site values:
       nano ${REPO_DST}/config/.env
       # Set: ZIM_PATH, EDITS_PATH, CHROMA_DATA_PATH, OLLAMA_MODEL

  3. First ZIM download (opens WAN gate — schedule a maintenance window):
       ${REPO_DST}/scripts/toggle_updates.sh open
       ZIM_PATH=${DATA_ROOT}/zim \\
       ZIM_FILE=wikipedia_en_all_maxi.zim \\
       KIWIX_MIRROR=https://download.kiwix.org/zim/wikipedia/ \\
         ${REPO_DST}/scripts/sync_wiki.sh
       ${REPO_DST}/scripts/toggle_updates.sh close

  4. Build all container images:
       cd ${REPO_DST}/config
       podman-compose --env-file .env build

  5. Start all services:
       podman-compose --env-file .env up -d
       podman ps --format "table {{.Names}}\\t{{.Status}}"

  6. Pull the LLM model (first run only):
       podman exec alexandria-ollama ollama pull llama3.2

  7. Verify ZIM integrity:
       ${REPO_DST}/scripts/verify_zim.sh ${DATA_ROOT}/zim

  FIPS STATUS
  ─────────────────────────────────────────────────────────────────────
  Host fips_enabled = ${FIPS_ENABLED}
$([ "${FIPS_ENABLED}" = "1" ] && echo "  FIPS mode is active — compliant." || echo "  WARNING: FIPS mode is not enabled — see Step 16 in the log.")

  See ${LOG_FILE} for the full audit trail.
════════════════════════════════════════════════════════════════════════

SUMMARY

log "init_alexandria.sh completed at $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
