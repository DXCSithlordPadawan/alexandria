#!/bin/sh
# verify_zim.sh — Standalone ZIM integrity checker
# ─────────────────────────────────────────────────────────────────────────────
# Compliance: NIST SI-7, Maintenance 6.1 (Weekly integrity verification)
# Run manually or from a cron/systemd job after every sync.
#
# Usage:
#   ./verify_zim.sh [/path/to/zim/dir]
#   Exit 0 = pass, Exit 1 = fail
# ─────────────────────────────────────────────────────────────────────────────
set -eu

ZIM_DIR="${1:-/mnt/pve/alexandria/zim}"
ZIM_FILE="${ZIM_FILE:-wikipedia_en_all_maxi.zim}"
FINAL_ZIM="${ZIM_DIR}/${ZIM_FILE}"
SHA_FILE="${ZIM_DIR}/${ZIM_FILE}.sha256"

log() {
    echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [verify_zim] $*"
}

if [ ! -f "${FINAL_ZIM}" ]; then
    log "ERROR: ZIM file not found: ${FINAL_ZIM}"
    exit 1
fi

if [ ! -f "${SHA_FILE}" ]; then
    log "ERROR: SHA256 file not found: ${SHA_FILE}"
    log "       Cannot verify integrity without checksum file."
    exit 1
fi

log "Verifying ${FINAL_ZIM}..."
expected=$(awk '{print $1}' "${SHA_FILE}")
actual=$(sha256sum "${FINAL_ZIM}" | awk '{print $1}')

if [ "${expected}" = "${actual}" ]; then
    log "PASS — checksum verified: ${actual}"
    exit 0
else
    log "FAIL — expected: ${expected}"
    log "FAIL — actual:   ${actual}"
    log "ACTION REQUIRED: ZIM file may be corrupted. Re-run sync_wiki.sh."
    exit 1
fi
