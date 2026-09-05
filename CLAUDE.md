# lycus

Terraform + Ansible to build a Hermes Agent host. Read `SPEC.md` for what the
machine is, `AUTOMATION.md` for how it is built, and `adr/adr.md` for why.

## Repo
`ca1ebd/lycus` — public, SSH key auth. Feature branches only, never push to main.
Git CLI for git operations; GitHub MCP for repo/PR/issue management.

**No attribution in commits or PRs.** No `Co-Authored-By`, no session links, no
"Generated with Claude Code". Besides being the standing preference, this repo's
`main` ruleset sets `require_extra_approval_for_unattributed_changes`, so a
co-author email that maps to no GitHub account blocks the merge.

## Structure

```
lycus/
├── terraform/{proxmox,digitalocean}/   # one root module per target, same output contract
├── ansible/
│   ├── site.yml                        # base -> user -> ssh_hardening -> docker -> devtools -> hermes -> restore
│   ├── molecule/default/               # container scenario run by CI
│   └── roles/
│       ├── base/                       # packages, swap, timezone, unattended-upgrades, guest agent
│       ├── user/                       # hermes user, keys, sudo, 0600 secrets file
│       ├── ssh_hardening/              # sshd_config, validated before restart
│       ├── docker/                     # engine + group membership
│       ├── devtools/                   # node, uv, terraform, gh, az, playwright, claude code
│       ├── hermes/                     # agent install + gateway systemd unit
│       └── restore/                    # rehydrate captured state (tagged `never`)
├── backup/capture.sh                   # capture state from a running host
└── adr/
```

## Things that look like bugs and are not

- **The Hermes installer runs as root.** It picks its layout from the effective
  uid, not a flag. As root it does a conventional system-wide install (its "FHS
  layout"): `/usr/local/lib/hermes-agent` + `/usr/local/bin/hermes`. As any other
  user: `~/.hermes/hermes-agent` + `~/.local/bin`. Changing this to
  `become_user: hermes` looks safer and just builds a different machine — the
  agent already runs unprivileged via the unit's `User=`. See adr/0002.
- **`install.sh` gets `--non-interactive --skip-setup`.** Its setup wizard and
  gateway offer are guarded by `(: </dev/tty)`, which is NOT enough under
  Ansible: `become` allocates a pseudo terminal, so the guard passes and the
  wizard blocks forever on input. The role calls `hermes gateway install`
  itself instead of relying on the offer.
- **The gateway is enabled but not started.** Starting it is a cutover decision;
  two gateways polling one bot token fight. Set `hermes_gateway_started: true`.
- **`vm_agent_enabled` defaults true on Proxmox.** It controls whether the VirtIO
  serial device exists at all, not just whether Terraform waits. With it false
  the guest's `qemu-guest-agent` has nothing to bind and cannot start.
  `vm_agent_timeout` bounds the wait instead. The device only appears after a
  full power cycle — stop/start, not reboot.
- **`acl` is in `base_packages`.** Required for any `become_user` to a non-root
  user: Ansible grants the target user access to its 0600 temp file with
  `setfacl` rather than world-reading it. Without it, every such task fails.
- **`user` role sets `append: true`.** The `docker` role adds the user to
  `docker`; without append the default replaces group membership and the two
  roles fight on every run.
- **No apt chromium.** On 24.04 that package is a stub for the snap, which drags
  in `cups`. The agent uses Playwright's own browsers. See adr/0003.

## Testing

```bash
cd ansible && molecule test
```

CI runs this per PR. The scenario skips network-heavy installers and covers the
host policy — which is where every real bug found so far has been.
