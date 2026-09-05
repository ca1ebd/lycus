# What a Lycus host is

The authoritative description of the machine, independent of how it gets built.
`AUTOMATION.md` covers the Terraform and Ansible that produce it.

Lycus is a single long-lived host running **Hermes Agent** and its messaging
gateway, plus enough developer tooling for the agent to do real work — build
containers, drive a browser, run Terraform, talk to GitHub and Azure.

It is deliberately a *pet*, not cattle. It accumulates state that matters:
conversation history, memories, skills, cron jobs. That state is what
`backup/capture.sh` and the `restore` role exist to move; everything else is
rebuildable from scratch.

## Operating system

Ubuntu 24.04 LTS. The Ansible roles assume Debian-family package names and apt
repositories throughout.

## Users and access

- A single unprivileged service account, **`hermes`**, owns the agent, its data
  and its workspace. Its password is locked — an SSH key is the only login path.
- Passwordless sudo via `/etc/sudoers.d/hermes`. There is no password to enter,
  so prompting would only be theatre.
- `hermes` is in `docker`, so it can use the daemon without sudo.
- sshd is hardened: no password authentication, no root login, public keys only.
  The config is validated with `sshd -t` before any restart, so a bad edit fails
  the run instead of locking everyone out.

### Secrets do not live in dotfiles

Credentials go in `~/.config/hermes-env`, mode `0600`, sourced from `.bashrc`.
They are never written into `.bashrc` itself. This is a direct response to the
original host, which exported a GitHub PAT in plain text from a world-readable
`.bashrc`.

Agent credentials (`ANTHROPIC_API_KEY`, `OPENROUTER_API_KEY`,
`TELEGRAM_BOT_TOKEN`) live in `~/.hermes/.env`, owned by `hermes`, mode `0600`.

## Hermes Agent

**Root installs the code; the `hermes` user runs it.**

- `install.sh` runs as root, so it resolves its **FHS layout** — the installer's
  name for a conventional system-wide install, after the Filesystem Hierarchy
  Standard, which puts locally-installed software under `/usr/local`. Code at
  `/usr/local/lib/hermes-agent`, command at `/usr/local/bin/hermes`. This is how
  Claude Code and Codex CLI install too.
- `HERMES_HOME` is `/home/hermes/.hermes`, so the agent owns its own state even
  though root installed the binary.
- The gateway runs from a **system** unit, `/etc/systemd/system/hermes-gateway.service`,
  with `User=hermes` / `Group=hermes`. **The agent process never has root.**

Two things about the installer are load-bearing and easy to get wrong:

1. It picks its layout from the *effective uid*, not from a flag. Running it as
   the `hermes` user instead produces `~/.hermes/hermes-agent` with the command
   in `~/.local/bin` — a working install, but a different one. It fails silently
   in the sense that nothing errors; you simply get the wrong machine.
2. It ends with an interactive setup wizard, and separately offers to install
   the gateway's systemd unit. Both are guarded by `(: </dev/tty)` — and that
   guard is **not** enough under Ansible, which allocates a pseudo terminal for
   `become`. `/dev/tty` therefore exists, the guard passes, and the wizard
   blocks on input that never comes. So the installer is invoked with
   `--non-interactive --skip-setup`, and the unit is created by calling
   `hermes gateway install` explicitly.

The gateway is **enabled but not started** by a normal provision run. Starting it
is a cutover step: a fresh host has no credentials, and during a migration the
old host still owns the bot token — two gateways polling one token fight over
updates.

## Memory and swap

A swap file at `/swapfile`, sized to roughly host RAM, with `vm.swappiness=10`.

This is not a performance tuning decision. Without swap the OOM killer
terminates the gateway outright and takes its in-memory conversation context
with it; with swap the host degrades slowly and leaves time to react. It was
added after exactly that incident. See `docs/swap-setup-spec.md`.

## Browser automation

The agent drives **Playwright's own downloaded browsers** under
`~/.cache/ms-playwright`. Chromium is *not* installed from apt.

On Ubuntu 24.04 the `chromium-browser` package is a transitional stub whose only
job is to install the snap, and that snap pulls in `cups` as a runtime
dependency — which on the original host meant a print server listening on
`0.0.0.0:631`, on a box with no printer and a public IP. What apt legitimately
provides is the system library and font layer those browsers link against.

## Firewall

The host runs **no local firewall**. On the homelab VLAN the UniFi gateway is
the boundary and the host has no public address, so `ufw` would be inherited
configuration rather than a decision.

This does not hold on a cloud target, where the host *does* have a public
address. There the boundary is the provider's firewall, defined alongside the
instance in `terraform/digitalocean/`.

## What is expected to be present

Docker with compose and buildx; Node.js 20 with `@devcontainers/cli`; uv;
Terraform; the GitHub CLI; the Azure CLI; Claude Code; ripgrep, ffmpeg, jq,
wireguard-tools and a C toolchain.

## State that cannot be rebuilt

Everything below survives a rebuild only because it is explicitly captured:

| Path | What it holds |
|---|---|
| `~/.hermes` | config, `state.db` (conversation history), memories, skills, cron jobs |
| `~/.ssh` | keys, including the GitHub deploy key |
| `~/.claude`, `~/.claude.json` | Claude Code config, per-project settings, MCP servers |
| `~/.wireguard` | tunnel config for reaching other networks |
| `~/Development/claude/*` | four of these repositories have **no git remote** and exist nowhere else |

Caches are deliberately *not* preserved: `~/.cache/ms-playwright`, `~/.npm` and
`~/.vscode-server` are rebuildable, and together they were most of why the
original host's disk sat at 95% full.
