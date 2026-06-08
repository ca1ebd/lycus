# lycus

Ansible automation to provision Ubuntu VMs with Hermes Agent (NousResearch).

## Repo
`ca1ebd/lycus` — SSH key auth. Feature branches only, never push to main. Git CLI for git ops; GitHub MCP for repo/PR/issue management.

## Structure

```
lycus/
├── ansible.cfg                        # inventory=inventory/hosts.ini, become=sudo
├── inventory/hosts.ini                # [hermes_servers] — fill in VM IPs before running
├── playbooks/hermes.yml               # entry point: hosts=hermes_servers, role=hermes
└── roles/hermes/
    ├── defaults/main.yml              # all tuneable vars (user, shell, groups, SSH keys, install URL)
    ├── handlers/main.yml              # restart sshd
    └── tasks/
        ├── main.yml                   # imports: user → ssh_hardening → install
        ├── user.yml                   # creates hermes user/group, locks password, adds SSH keys, sudoers NOPASSWD
        ├── ssh_hardening.yml          # sshd_config: PasswordAuthentication no, PermitRootLogin no, PubkeyAuthentication yes
        └── install.yml                # runs official install.sh as hermes user, patches PATH in .bashrc/.profile
```

## Key design decisions

- **Dedicated `hermes` user**: all Hermes Agent activity runs under this user, not the bootstrap user.
- **Password locked**: `password_lock: true` + `PasswordAuthentication no` — SSH key is the only login path.
- **Passwordless sudo**: `NOPASSWD:ALL` in `/etc/sudoers.d/hermes` — no password to enter anyway.
- **Idempotent install**: checks for `~/.local/bin/hermes` before running the install script.
- **SSH keys in defaults**: `hermes_ssh_public_keys` list in `defaults/main.yml` — add keys there.

## Key variables (`roles/hermes/defaults/main.yml`)

| Variable | Default | Purpose |
|---|---|---|
| `hermes_user` | `hermes` | User created on the VM |
| `hermes_user_shell` | `/bin/bash` | Login shell |
| `hermes_user_groups` | `[sudo]` | Supplemental groups |
| `hermes_ssh_public_keys` | keys from this server's authorized_keys | Keys added to authorized_keys |
| `hermes_install_script` | `https://hermes-agent.nousresearch.com/install.sh` | Installer URL |

## Running

```bash
# Fill in inventory first
vim inventory/hosts.ini   # ansible_host=<IP> ansible_user=ubuntu (or root)

ansible-playbook playbooks/hermes.yml
```

## Hermes Agent

- Installed via official one-liner; handles Python 3.11, Node.js 22, uv, ripgrep, ffmpeg
- Binary lands at `~/.local/bin/hermes`
- Post-install config: `hermes model` (select LLM provider), `hermes gateway setup` (messaging)
- Data dir: `~/.hermes/` (override with `HERMES_HOME`)
- Docs: https://hermes-agent.nousresearch.com/docs
