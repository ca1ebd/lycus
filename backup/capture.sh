#!/usr/bin/env bash
# Capture the irreplaceable state from a running Lycus host.
#
# Everything this does NOT capture is rebuildable by ansible/site.yml: packages,
# toolchain, services, and the ~948 MB Playwright browser cache (`playwright
# install` regenerates it), ~/.npm, and ~/.vscode-server. Those three are most
# of what made the old droplet's disk look full, and carrying them across would
# just move the problem.
#
# Run this on the SOURCE host. Output is a single tarball for roles/restore.
set -euo pipefail

USER_NAME="${LYCUS_USER:-hermes}"
HOME_DIR="/home/${USER_NAME}"
OUT="${1:-/tmp/lycus-backup-$(date +%Y%m%d-%H%M%S).tar.gz}"
GATEWAY="${LYCUS_GATEWAY_SERVICE:-hermes-gateway}"

log() { printf '==> %s\n' "$*" >&2; }

# state.db is SQLite in WAL mode. Copying it hot risks capturing a torn database
# with a live WAL, so stop the writer first and checkpoint.
gateway_was_running=false
if systemctl is-active --quiet "${GATEWAY}" 2>/dev/null; then
  gateway_was_running=true
  log "Stopping ${GATEWAY} so state.db can be quiesced"
  sudo systemctl stop "${GATEWAY}"
fi

restore_gateway() {
  if [ "${gateway_was_running}" = true ]; then
    log "Restarting ${GATEWAY}"
    sudo systemctl start "${GATEWAY}" || true
  fi
}
trap restore_gateway EXIT

if [ -f "${HOME_DIR}/.hermes/state.db" ] && command -v sqlite3 >/dev/null 2>&1; then
  log "Checkpointing state.db WAL"
  sqlite3 "${HOME_DIR}/.hermes/state.db" 'PRAGMA wal_checkpoint(TRUNCATE);' || true
fi

INCLUDE=(
  ".hermes"
  ".ssh"
  ".claude"
  ".claude.json"
  ".wireguard"
  ".gitconfig"
  ".config"
  ".azure"
  ".docker"
  "projects"
  "resume-tailoring"
)

EXCLUDE=(
  --exclude=".hermes/audio_cache"
  --exclude=".hermes/image_cache"
  --exclude=".hermes/models_dev_cache.json"
  --exclude=".hermes/cache"
  --exclude=".claude/plugins/cache"
  --exclude="**/node_modules"
  --exclude="**/.terraform"
)

present=()
for path in "${INCLUDE[@]}"; do
  if [ -e "${HOME_DIR}/${path}" ]; then
    present+=("${path}")
  else
    log "skipping ${path} (not present)"
  fi
done

log "Writing ${OUT}"
tar czf "${OUT}" -C "${HOME_DIR}" "${EXCLUDE[@]}" "${present[@]}"

log "Done: $(du -h "${OUT}" | cut -f1) at ${OUT}"
log "Repos with no git remote must be captured separately — see backup/README.md"
