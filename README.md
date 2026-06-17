# lycus

Ansible automation to provision Ubuntu VMs with [Hermes Agent](https://hermes-agent.nousresearch.com) from NousResearch.

## What it does

- Creates a dedicated `hermes` user with passwordless sudo
- Adds your SSH public key to the user's `authorized_keys`
- Hardens SSH: disables password auth and root login, enforces pubkey-only
- Installs Hermes Agent via the official install script

## Prerequisites

- Ansible installed on your local machine
- A target Ubuntu VM reachable over SSH
- An SSH key already authorized on the VM for the bootstrap user (e.g. `ubuntu`)

## Usage

1. Add your VM to the inventory:

```yaml
# inventory/hosts.yml
all:
  children:
    hermes_servers:
      hosts:
        hermes-vm:
          ansible_host: 192.168.1.100
          ansible_user: ubuntu
      vars:
        ansible_python_interpreter: /usr/bin/python3
```

2. Run the playbook:

```bash
ansible-playbook -i inventory/hosts.yml playbooks/hermes.yml
```

## Configuration

Variables are defined in `roles/hermes/defaults/main.yml`. Override them in your inventory or with `-e` at runtime.

| Variable | Default | Purpose |
|---|---|---|
| `hermes_user` | `hermes` | User created on the VM |
| `hermes_user_shell` | `/bin/bash` | Login shell |
| `hermes_user_groups` | `[sudo]` | Supplemental groups |
| `hermes_ssh_public_keys` | keys from this machine's `authorized_keys` | Keys added to `authorized_keys` |
| `hermes_install_script` | `https://hermes-agent.nousresearch.com/install.sh` | Installer URL |

## Hermes Agent

- Installed via official one-liner; handles Python 3.11, Node.js 22, uv, ripgrep, ffmpeg
- Binary lands at `~/.local/bin/hermes`
- Post-install: run `hermes model` to select an LLM provider, `hermes gateway setup` for messaging
- Data dir: `~/.hermes/` (override with `HERMES_HOME`)
- Docs: https://hermes-agent.nousresearch.com/docs
