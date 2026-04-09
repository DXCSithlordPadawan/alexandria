#!/bin/sh
# toggle_updates.sh — WAN firewall gate controller
# ─────────────────────────────────────────────────────────────────────────────
# Compliance: NIST AC-4 (Information Flow Enforcement)
# Toggles the Proxmox firewall Security Group 'alexandria-wan' on/off.
# Restricted to SysAdmin role (checked via group membership).
#
# Usage:
#   ./toggle_updates.sh open   — enable outbound WAN for sync window
#   ./toggle_updates.sh close  — re-enable default-deny outbound
#
# Requirements:
#   - Must run on the Proxmox host (not inside a container)
#   - Caller must be in group 'alexandria-admin'
#   - pvesh must be available ($PATH)
# ─────────────────────────────────────────────────────────────────────────────
set -eu

REQUIRED_GROUP="alexandria-admin"
FW_GROUP="${PVE_FW_GROUP:-alexandria-wan}"
ACTION="${1:-}"
TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
LOG_FILE="/var/log/alexandria/wan-gate.log"

log() {
    echo "[${TIMESTAMP}] [toggle_updates] $*" | tee -a "${LOG_FILE}"
}

# ── Authorisation check ───────────────────────────────────────────────────────
CALLER="${SUDO_USER:-$(id -un)}"
if ! id -nG "${CALLER}" | grep -qw "${REQUIRED_GROUP}"; then
    log "DENIED: ${CALLER} is not in group ${REQUIRED_GROUP}"
    exit 1
fi

# ── Argument validation ───────────────────────────────────────────────────────
case "${ACTION}" in
    open|close) ;;
    *)
        echo "Usage: $0 open|close" >&2
        exit 2
        ;;
esac

# ── Ensure log directory exists ───────────────────────────────────────────────
mkdir -p "$(dirname "${LOG_FILE}")"

# ── Apply firewall change via pvesh ───────────────────────────────────────────
if [ "${ACTION}" = "open" ]; then
    log "Opening WAN gate for group '${FW_GROUP}' (caller: ${CALLER})"
    # Enable the security group on the cluster firewall
    pvesh set /cluster/firewall/groups/"${FW_GROUP}" --enable 1
    log "WAN gate OPEN — sync window active"
else
    log "Closing WAN gate for group '${FW_GROUP}' (caller: ${CALLER})"
    pvesh set /cluster/firewall/groups/"${FW_GROUP}" --enable 0
    log "WAN gate CLOSED — default-deny restored"
fi
