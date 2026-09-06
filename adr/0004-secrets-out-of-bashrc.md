# 0004: Secrets in a 0600 file, not in `.bashrc`

Date: 2026-09-05
Status: Accepted

## Context

The original host exported a GitHub personal access token in plain text from
`~/.bashrc`:

```bash
export GITHUB_PAT="github_pat_..."
```

`.bashrc` is mode `0644`. It is also a file that gets read, diffed, pasted into
issues, and echoed while debugging — it is one of the most casually-handled
files on a machine. A long-lived credential with repository write access is
close to the worst thing to put there.

The token was in fact exposed during the migration work itself: reading the file
to inventory the host's shell configuration printed it into a session
transcript. That is not a hypothetical leak path; it is the normal way that file
gets handled.

## Decision

Credentials live in `~/.config/hermes-env`, mode `0600`, owned by `hermes`, and
`.bashrc` sources it:

```bash
[ -f "$HOME/.config/hermes-env" ] && . "$HOME/.config/hermes-env"
```

Values come from `hermes_user_env` in `ansible/group_vars/all/vault.yml`,
encrypted with ansible-vault. The task that writes the file sets `no_log: true`.

Agent credentials stay where Hermes expects them, in `~/.hermes/.env`, also
`0600` and owned by `hermes`.

Molecule asserts both halves: that `~/.config/hermes-env` exists at `0600` owned
by `hermes`, **and** that `GITHUB_PAT=` does not appear in `.bashrc`. The second
assertion is the one that matters — it fails if anyone reintroduces the original
pattern.

## Consequences

Shell environment and secret material are separated, so `.bashrc` can be read
and shared freely.

The mode is still only file permissions: anything running as `hermes`, including
the agent, can read the file. This is a defence against casual exposure, not
against an attacker who already has the account. Real secret isolation would
need a secrets manager and short-lived credentials, which is disproportionate
for a single-user homelab host.

The compromised token must be rotated. Moving it does not un-expose it.
