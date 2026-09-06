#!/usr/bin/env bash
# Capture state from a running Lycus host.
#
# Two tiers, because they have very different costs:
#
#   agent  (default) — everything that makes the agent *itself*: config,
#                      credentials, skills, memories, kanban, cron. ~19 MB of
#                      plain files. Nothing here is a live database, so the
#                      gateway does not need stopping.
#
#   history (--with-history) — ~/.hermes/state.db, which holds conversation
#                      history and nothing else: a `messages` table, a
#                      `sessions` table, and FTS indexes over them. ~35 MB plus
#                      a WAL. The agent is fully functional without it; you lose
#                      recall and search of past conversations. Because it is a
#                      live SQLite database in WAL mode, capturing it means
#                      stopping the writer first.
#
# Not captured either way: ~/.cache/ms-playwright, ~/.npm, ~/.vscode-server and
# ~/.hermes/logs — all rebuildable, and together most of why the old host's disk
# was full.
set -euo pipefail

USER_NAME="${LYCUS_USER:-hermes}"
HOME_DIR="/home/${USER_NAME}"
HERMES_HOME="${HERMES_HOME:-${HOME_DIR}/.hermes}"
GATEWAY="${LYCUS_GATEWAY_SERVICE:-hermes-gateway}"
WITH_HISTORY=false
OUT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --with-history) WITH_HISTORY=true; shift ;;
    -h|--help) sed -n '2,25p' "$0"; exit 0 ;;
    *) OUT="$1"; shift ;;
  esac
done
OUT="${OUT:-/tmp/lycus-backup-$(date +%Y%m%d-%H%M%S).tar.gz}"

log() { printf '==> %s\n' "$*" >&2; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# Refuse to run from inside the gateway's own cgroup.
#
# The Hermes gateway is a system service with KillMode=mixed, and anything it
# spawns stays in its cgroup — systemd tracks by cgroup, not by parent, so
# daemonizing does not escape it. Agents launched by the gateway therefore live
# there too, and the `gateway stop` below would SIGKILL the very process running
# this script, mid-backup. That happened repeatedly before it was diagnosed.
#
# Launch agents with `systemd-run --scope` (see the claude-remote-sessions
# skill), or run this from an ordinary login shell.
if grep -q 'hermes-gateway\.service' /proc/self/cgroup 2>/dev/null; then
  die "running inside hermes-gateway.service's cgroup — stopping the gateway would kill this script. Relaunch under 'systemd-run --scope' or run from a login shell."
fi

# Everything that defines the agent. All plain files — no live databases, so
# these are safe to read while the gateway runs.
AGENT_PATHS=(
  ".hermes/config.yaml"
  ".hermes/.env"
  ".hermes/auth.json"
  ".hermes/memories"
  ".hermes/skills"
  ".hermes/cron"
  ".hermes/kanban.db"
  ".hermes/channel_directory.json"
  # Paired user identities. Without this the gateway starts, connects, and then
  # refuses its own owner with "I don't recognize you yet" plus a fresh pairing
  # code — the migration looks successful right up until someone messages it.
  ".hermes/pairing"
  ".hermes/SOUL.md"
  ".ssh"
  ".claude"
  ".claude.json"
  ".wireguard"
  ".gitconfig"
  ".config"
)

if [ "${WITH_HISTORY}" = true ]; then
  # state.db is SQLite in WAL mode. Copying it hot risks a torn database with an
  # unmerged WAL, so stop the writer and checkpoint first.
  if systemctl is-active --quiet "${GATEWAY}" 2>/dev/null; then
    log "Stopping ${GATEWAY} so state.db can be quiesced"
    # Prefer the CLI over systemctl: `gateway stop` drains in-flight work and
    # shuts the agent down cleanly, where systemctl just delivers SIGTERM.
    # --system because the unit is system-scope (see adr/0002).
    if command -v hermes >/dev/null 2>&1; then
      sudo hermes gateway stop --system || sudo systemctl stop "${GATEWAY}"
    else
      sudo systemctl stop "${GATEWAY}"
    fi
    trap 'log "Restarting ${GATEWAY}"; sudo systemctl start "${GATEWAY}" || true' EXIT
  fi
  # Merge the WAL into the main database. Without this we would capture
  # state.db while its most recent messages still live in a separate -wal file,
  # producing a database that is silently missing data. Not every host has the
  # sqlite3 CLI, so fall back to Python's module, which is always present here.
  if [ -f "${HERMES_HOME}/state.db" ]; then
    log "Checkpointing state.db WAL"
    if command -v sqlite3 >/dev/null 2>&1; then
      sqlite3 "${HERMES_HOME}/state.db" 'PRAGMA wal_checkpoint(TRUNCATE);' || true
    else
      python3 - "${HERMES_HOME}/state.db" <<'PYEOF' || true
import sqlite3, sys
con = sqlite3.connect(sys.argv[1])
con.execute('PRAGMA wal_checkpoint(TRUNCATE);')
con.close()
PYEOF
    fi
  fi

  AGENT_PATHS+=(".hermes/state.db")
  # Belt and braces: if the checkpoint did not fully drain the WAL, carry the
  # sidecar files too rather than shipping a torn database.
  for sidecar in "state.db-wal" "state.db-shm"; do
    [ -f "${HERMES_HOME}/${sidecar}" ] && AGENT_PATHS+=(".hermes/${sidecar}")
  done
else
  log "Skipping conversation history (state.db). Pass --with-history to include it."
fi

present=()
for p in "${AGENT_PATHS[@]}"; do
  if [ -e "${HOME_DIR}/${p}" ]; then present+=("${p}"); else log "skipping ${p} (absent)"; fi
done

log "Writing ${OUT}"
tar czf "${OUT}" -C "${HOME_DIR}" \
  --exclude='.claude/plugins/cache' \
  --exclude='**/node_modules' \
  --exclude='**/.terraform' \
  "${present[@]}"

log "Done: $(du -h "${OUT}" | cut -f1) at ${OUT}"
log "Repos with no git remote are captured separately — see backup/README.md"
