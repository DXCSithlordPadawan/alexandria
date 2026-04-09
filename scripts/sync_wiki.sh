#!/bin/sh
# sync_wiki.sh — Weekly ZIM archive downloader with integrity verification
# ─────────────────────────────────────────────────────────────────────────────
# Compliance: NIST SI-7 (Software, Firmware, Information Integrity)
# Runs inside the updater container as unprivileged user 'syncer'.
# Also callable directly from the systemd service on the Proxmox host.
#
# Behaviour:
#   1. Sleep for SYNC_INTERVAL_SECONDS (default 7 days)
#   2. Download the new ZIM and its .sha256 checksum file
#   3. Verify the checksum — abort on mismatch (no partial replacement)
#   4. Atomically replace the existing ZIM via rename
#   5. Restart the kiwix container (podman signal from host systemd unit)
#
# Environment (set in compose or .env):
#   KIWIX_MIRROR          — base URL of Kiwix mirror
#   ZIM_FILE              — filename of the ZIM archive
#   SYNC_INTERVAL_SECONDS — sleep interval between syncs
# ─────────────────────────────────────────────────────────────────────────────
set -eu

: "${KIWIX_MIRROR:=https://download.kiwix.org/zim/wikipedia/}"
: "${ZIM_FILE:=wikipedia_en_all_maxi.zim}"
: "${SYNC_INTERVAL_SECONDS:=604800}"

ZIM_DIR="/data/zim"
ZIM_URL="${KIWIX_MIRROR}${ZIM_FILE}"
SHA_URL="${ZIM_URL}.sha256"
TMP_ZIM="${ZIM_DIR}/${ZIM_FILE}.tmp"
TMP_SHA="${ZIM_DIR}/${ZIM_FILE}.sha256.tmp"
FINAL_ZIM="${ZIM_DIR}/${ZIM_FILE}"

log() {
    echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [sync_wiki] $*"
}

download_with_retry() {
    url="$1"
    dest="$2"
    attempts=3
    i=1
    while [ "${i}" -le "${attempts}" ]; do
        log "Downloading ${url} (attempt ${i}/${attempts})"
        if wget -q --no-verbose --timeout=60 --tries=1 -O "${dest}" "${url}"; then
            return 0
        fi
        log "WARNING: Download attempt ${i} failed"
        i=$((i + 1))
        sleep 30
    done
    log "ERROR: All download attempts failed for ${url}"
    return 1
}

verify_checksum() {
    sha_file="$1"
    zim_file="$2"
    log "Verifying SHA-256 checksum..."
    # The .sha256 file contains: <hash>  <filename>
    expected=$(awk '{print $1}' "${sha_file}")
    actual=$(sha256sum "${zim_file}" | awk '{print $1}')
    if [ "${expected}" = "${actual}" ]; then
        log "Checksum OK: ${actual}"
        return 0
    fi
    log "ERROR: Checksum mismatch — expected ${expected}, got ${actual}"
    return 1
}

cleanup() {
    rm -f "${TMP_ZIM}" "${TMP_SHA}"
}

# Trap to ensure temp files are removed on exit/error
trap cleanup EXIT INT TERM

# ── Main loop ─────────────────────────────────────────────────────────────────
while true; do
    log "Sleeping ${SYNC_INTERVAL_SECONDS}s before next sync..."
    sleep "${SYNC_INTERVAL_SECONDS}"

    log "Starting sync of ${ZIM_FILE}"

    if ! download_with_retry "${SHA_URL}" "${TMP_SHA}"; then
        log "Skipping this sync cycle — SHA256 download failed"
        continue
    fi

    if ! download_with_retry "${ZIM_URL}" "${TMP_ZIM}"; then
        log "Skipping this sync cycle — ZIM download failed"
        continue
    fi

    if ! verify_checksum "${TMP_SHA}" "${TMP_ZIM}"; then
        log "Skipping this sync cycle — integrity check failed"
        continue
    fi

    # Atomic rename — replace in one syscall (no window where file is absent)
    mv "${TMP_ZIM}" "${FINAL_ZIM}"
    mv "${TMP_SHA}" "${ZIM_DIR}/${ZIM_FILE}.sha256"

    log "ZIM updated successfully. Kiwix container will reload on next restart."
    log "To apply immediately, run: podman restart alexandria-wiki"
done
