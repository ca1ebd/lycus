# 0005: Rebuild configuration, restore only state

Date: 2026-09-05
Status: Accepted

## Context

Moving the agent host to new hardware could have been a disk-level migration —
image the droplet, restore it, done. Instead the host is rebuilt from Ansible
and only its irreplaceable state is carried over.

The host had accumulated three years of drift: a hand-created swap file, a
hand-dropped Terraform binary in `/usr/local/bin`, a snap-installed browser
nothing used, an exposed print server, a token in a dotfile, and a root
filesystem at 95% full. Roughly 8 GB of that disk was rebuildable cache —
`~/.vscode-server` at 6.4 GB, `~/.npm` at 1.5 GB, `~/.cache/ms-playwright` at
948 MB.

A disk-level migration preserves all of that faithfully, including the parts
nobody wants.

## Decision

`ansible/site.yml` rebuilds packages, toolchain and services from scratch.
`backup/capture.sh` captures only what cannot be rebuilt — `~/.hermes` (config,
`state.db`, memories, skills, cron jobs), `~/.ssh`, `~/.claude`, `~/.wireguard`,
`~/.gitconfig`, and the four repositories in the workspace that have no git
remote and exist nowhere else. Caches are excluded explicitly.

`restore` is tagged `never`, so it is skipped unless asked for. The sequence is:
provision, prove the host clean and empty, *then* lay state on top. It also
refuses to run if `state.db` already exists unless `restore_force=true`.

`capture.sh` stops the gateway before reading `state.db` and checkpoints its
WAL, then restarts it via an `EXIT` trap. SQLite in WAL mode copied hot can
yield a torn database.

## Consequences

The new host is the documented machine rather than an accumulation of history,
and the disk-pressure problem does not travel with it. Every piece of
configuration on it exists because a role puts it there, so the next rebuild is
cheap.

The cost is real: anything configured by hand and never written down is lost.
That is the point — it forces the drift to surface now, while both hosts exist,
rather than at the next rebuild. The mitigation is that the old host is kept
powered off rather than destroyed for a soak period, so anything missed is
recoverable.

Restore takes a brief outage by design. The gateway must be stopped on the
source before capture and started on the destination after, and the two must
never overlap: two gateways polling one Telegram bot token fight over updates.
