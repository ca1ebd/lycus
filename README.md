# lycus

Terraform and Ansible to build a host running [Hermes Agent](https://hermes-agent.nousresearch.com)
from NousResearch — the instance, the agent, its messaging gateway, and enough
developer tooling for the agent to do real work.

Two layers, deliberately separable. **Terraform** creates the instance, one root
module per target. **Ansible** turns any reachable Ubuntu 26.04 host into a
Lycus host and neither knows nor cares which target produced it.

```
terraform/proxmox/         ->  \
                                 >  host_ip, ssh_user, ssh_private_key_path  ->  ansible/site.yml
terraform/digitalocean/    ->  /
```

## Documentation

| Document | What it covers |
|---|---|
| [SPEC.md](SPEC.md) | What a Lycus host **is**, independent of how it is built |
| [AUTOMATION.md](AUTOMATION.md) | The Terraform and Ansible that build it |
| [adr/](adr/adr.md) | **Why** it looks this way — the non-obvious tradeoffs |
| [backup/README.md](backup/README.md) | What is captured on a migration, and what is not |

If you are about to change something and it seems obviously wrong, read the ADRs
first. Several of the choices here look like mistakes and are not — see in
particular [0002](adr/0002-root-installs-hermes-user-runs-it.md), on why the
installer runs as root even though the agent must not.

## Quick start

```bash
# 1. create the instance
cd terraform/proxmox
cp terraform.tfvars.example terraform.tfvars    # add your SSH public keys
terraform init && terraform apply

# 2. point Ansible at it
terraform output -raw inventory_yaml > ../../ansible/inventory/hosts.yml

# 3. build the host
cd ../..
ansible-galaxy collection install -r ansible/requirements.yml
ansible-playbook -i ansible/inventory/hosts.yml ansible/site.yml
```

Proxmox credentials come from `PROXMOX_VE_ENDPOINT` / `PROXMOX_VE_API_TOKEN`;
DigitalOcean from `DIGITALOCEAN_TOKEN`. Nothing goes in tfvars but public keys
and sizing.

The gateway is left **enabled but stopped**. Starting it is a deliberate step —
see [AUTOMATION.md](AUTOMATION.md#three-things-about-this-that-are-not-obvious).

## What you get

An Ubuntu 26.04 host running Hermes Agent as an unprivileged `hermes` user, with
Docker, Node.js, uv, Terraform, the GitHub and Azure CLIs, Claude Code, and
Playwright-driven browsers. Hardened sshd, a swap file sized to survive OOM
pressure, and secrets kept out of dotfiles.

Full detail in [SPEC.md](SPEC.md).

## Testing

```bash
pip install -r requirements.txt
cd ansible && molecule test
```

Converges `base`, `user`, `ssh_hardening` and `docker` in a container, checks
idempotence, and asserts the resulting host policy. CI runs this on every pull
request.
