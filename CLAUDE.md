# lycus

Ansible automation to provision Ubuntu VMs with Hermes Agent (NousResearch).

## Repo
`ca1ebd/lycus` — SSH key auth. Feature branches only, never push to main. Git CLI for git ops; GitHub MCP for repo/PR/issue management.

## Structure

```
lycus/
├── .github/workflows/ci.yml           # runs molecule on PRs; comments the output back on failure
├── requirements.txt                   # ansible + molecule, for CI and local runs
├── docs/swap-setup-spec.md            # swap sizing/swappiness spec — not yet implemented as tasks
├── inventory/hosts.yml                # hermes_servers group — fill in VM IPs before running
├── playbooks/hermes.yml               # entry point: hosts=hermes_servers, become=true, role=hermes
└── roles/hermes/
    ├── defaults/main.yml              # all tuneable vars (user, shell, groups, SSH keys, install URL, toggles)
    ├── molecule/default/              # docker-based scenario: converge, verify, idempotence
    └── tasks/
        ├── main.yml                   # imports: user → ssh_hardening → install (install gated by a flag)
        ├── user.yml                   # prereq packages, hermes user/group, locked password, SSH keys, sudoers NOPASSWD
        ├── ssh_hardening.yml          # sshd_config directives, validates with sshd -t, restarts only on change
        └── install.yml                # runs official install.sh, patches PATH in .bashrc/.profile
```

## Key design decisions

- **Dedicated `hermes` user**: all Hermes Agent activity runs under this user, not the bootstrap user.
- **Password locked**: `password_lock: true` + `PasswordAuthentication no` — SSH key is the only login path.
- **Passwordless sudo**: `NOPASSWD:ALL` in `/etc/sudoers.d/hermes` — no password to enter anyway.
- **Idempotent install**: checks for `~/.local/bin/hermes` before running the install script.
- **SSH keys in defaults**: `hermes_ssh_public_keys` list in `defaults/main.yml` — add keys there.
- **No handler for sshd**: each `sshd_config` edit registers its result and the restart is conditional on
  them, so a converged host doesn't bounce sshd on every run. The config is validated with `sshd -t`
  before the restart, so a bad edit fails the play instead of locking you out.
- **The sshd unit name is resolved from facts**: Debian and Ubuntu ship `ssh.service` with *no* `sshd`
  alias, RHEL-family ships `sshd`. Hardcoding either one breaks the other — see `hermes_sshd_service`.
- **`hermes_install_agent`**: set false to provision the user, hardening and sudoers without running the
  installer. Molecule uses this — the installer pulls a full Python/Node toolchain over the network,
  which makes CI slow and non-deterministic.

## Testing

```bash
pip install -r requirements.txt
cd roles/hermes && molecule test
```

Runs converge, an idempotence pass, and `verify.yml` against an Ubuntu 24.04 container.
