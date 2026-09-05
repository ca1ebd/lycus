# 0002: Root installs Hermes, the `hermes` user runs it

Date: 2026-09-05
Status: Accepted

## Context

Hermes Agent should not run as root. The question was what "installed as a
separate user, not root" should mean mechanically, and the answer is not obvious
because `install.sh` chooses its layout from the **effective uid**, not from any
flag:

- as root on Linux: code at `/usr/local/lib/hermes-agent`, command in
  `/usr/local/bin`, data at `$HERMES_HOME`
- as any other user: code at `$HERMES_HOME/hermes-agent`, command in
  `~/.local/bin`

Both produce a working install. The role originally ran the installer with
`become_user: hermes`, which silently produced the second layout while production
ran the first. Nothing errored; the machine was simply different from the one
that was documented.

A related trap: the installer offers to install the gateway's systemd unit only
behind an interactive prompt, and short-circuits earlier at
`if ! (: </dev/tty)` with "Gateway setup skipped (no terminal available)". Under
Ansible there is never a TTY, so that offer is permanently unreachable.

## Decision

`install.sh` runs as **root**, producing the FHS layout, with `HERMES_HOME` set
to `/home/hermes/.hermes` so the agent still owns its own data. The gateway runs
from a **system** unit with `User=hermes` / `Group=hermes`.

The agent process never has root. Only the install step does.

The role calls `hermes gateway install` explicitly, since the installer cannot.

### Alternative considered: a fully user-scoped install

Running everything as `hermes` — code in `~/.hermes/hermes-agent`, a *user*
systemd unit — is the stricter reading, and was rejected for cost rather than
principle. `hermes gateway install` as non-root writes to
`~/.config/systemd/user/`, which then needs `loginctl enable-linger` to survive
logout and start at boot, plus a reachable D-Bus session. Ansible's `become_user`
provides no login session and therefore no `XDG_RUNTIME_DIR`, so this needs
explicit workarounds in every task that touches the service. The security
benefit over `User=hermes` on a system unit is negligible: in both cases the
agent runs unprivileged and cannot write its own code.

## Consequences

The code at `/usr/local/lib/hermes-agent` is root-owned and world-readable. The
agent can execute it but cannot modify it — arguably better than a user-scoped
install, where the agent could rewrite its own program.

Because the installer runs as root, anything it creates under `HERMES_HOME`
lands root-owned, so the role fixes ownership afterwards.

This decision is easy to "fix" incorrectly. Changing the installer task to
`become_user: hermes` looks like a security improvement and is not. There is an
assertion in `roles/hermes/tasks/gateway.yml` that reads back the unit's `User=`
and fails the run if it is ever anything but `hermes`, so the property that
actually matters is enforced rather than assumed.
