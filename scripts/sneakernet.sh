#!/bin/sh
# sneakernet.sh — Air-gap physical import helper
# ─────────────────────────────────────────────────────────────────────────────
# Compliance: NIST MP-5 (Media Transport), FIPS 140-3 (validated USB device)
# Use when the Proxmox host is fully air-gapped and cannot reach Kiwix mirrors.
#
# Procedure (Section 8 of PRD):
#   1. On internet-facing workstation: download ZIM + .sha256
#   2. Copy to FIPS 140-3 validated hardware-encrypted USB
#   3. Insert USB into Proxmox host and run THIS script as root
#
# Usage:
#   ./sneakernet.sh /dev/sdb1
#
# The script will:
#   - Mount the USB (read-only)
#   - Verify the SHA-256 checksum
#   - Copy the ZIM to /mnt/pve/alexandria/zim atomically
#   - Unmount the USB
#   - Restart the kiwix container
# ─────────────────────────────────────────────────────────────────────────────
set -eu

DEVICE="${1:-}"
ZIM_FILE="${ZIM_FILE:-wikipedia_en_all_maxi.zim}"
DEST_DIR="${ZIM_PATH:-/mnt/pve/alexandria/zim}"
MOUNT_POINT="/mnt/alexandria-usb"
LOG_FILE="/var/log/alexandria/sneakernet.log"
TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

log() {
    echo "[${TIMESTAMP}] [sneakernet] $*" | tee -a "${LOG_FILE}"
}

# ── Validation ────────────────────────────────────────────────────────────────
if [ -z "${DEVICE}" ]; then
    echo "Usage: $0 /dev/sdX1" >&2
    exit 2
fi

if [ "$(id -u)" -ne 0 ]; then
    log "ERROR: Must run as root"
    exit 1
fi

if [ ! -b "${DEVICE}" ]; then
    log "ERROR: ${DEVICE} is not a block device"
    exit 1
fi

mkdir -p "${LOG_FILE%/*}"
mkdir -p "${MOUNT_POINT}"

# ── Mount USB read-only ───────────────────────────────────────────────────────
log "Mounting ${DEVICE} at ${MOUNT_POINT} (read-only)"
mount -o ro,noexec,nosuid,nodev "${DEVICE}" "${MOUNT_POINT}"

# Ensure unmount on exit
cleanup() {
    log "Unmounting ${MOUNT_POINT}"
    umount "${MOUNT_POINT}" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# ── Find files ────────────────────────────────────────────────────────────────
USB_ZIM="${MOUNT_POINT}/${ZIM_FILE}"
USB_SHA="${USB_ZIM}.sha256"

if [ ! -f "${USB_ZIM}" ]; then
    log "ERROR: ZIM file not found on media: ${USB_ZIM}"
    exit 1
fi

if [ ! -f "${USB_SHA}" ]; then
    log "ERROR: SHA256 file not found on media: ${USB_SHA}"
    exit 1
fi

# ── Verify checksum ───────────────────────────────────────────────────────────
log "Verifying SHA-256 checksum on source media..."
expected=$(awk '{print $1}' "${USB_SHA}")
actual=$(sha256sum "${USB_ZIM}" | awk '{print $1}')

if [ "${expected}" != "${actual}" ]; then
    log "ERROR: Checksum mismatch on source media — import aborted"
    log "       Expected: ${expected}"
    log "       Actual:   ${actual}"
    exit 1
fi

log "Checksum verified: ${actual}"

# ── Copy atomically ───────────────────────────────────────────────────────────
TMP_DEST="${DEST_DIR}/${ZIM_FILE}.import.tmp"
log "Copying ${ZIM_FILE} to ${DEST_DIR} ..."
cp "${USB_ZIM}" "${TMP_DEST}"

# Verify the copy
actual_copy=$(sha256sum "${TMP_DEST}" | awk '{print $1}')
if [ "${expected}" != "${actual_copy}" ]; then
    log "ERROR: Post-copy checksum mismatch — removing corrupted copy"
    rm -f "${TMP_DEST}"
    exit 1
fi

mv "${TMP_DEST}" "${DEST_DIR}/${ZIM_FILE}"
cp "${USB_SHA}" "${DEST_DIR}/${ZIM_FILE}.sha256"

log "Import complete: ${DEST_DIR}/${ZIM_FILE}"
log "Restarting Kiwix container..."
podman restart alexandria-wiki && log "Kiwix restarted successfully." || log "WARNING: podman restart failed — restart manually"
