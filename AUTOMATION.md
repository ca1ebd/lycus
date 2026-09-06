# How a Lycus host gets built

`SPEC.md` describes the machine. This describes the automation that produces it.

Two layers, deliberately separable:

- **Terraform** creates the instance. One root module per target under
  `terraform/<target>/`, each satisfying the same output contract.
- **Ansible** turns any reachable Ubuntu 26.04 host into a Lycus host. It does
  not know or care which target produced it.

That split is the point. Lycus is a standalone project that happens to be
pointed at a homelab; swapping the target must not touch the configuration
layer.

## Repository layout

```
lycus/
├── terraform/
│   ├── proxmox/            # the homelab target
│   └── digitalocean/       # the cloud target
├── ansible/
│   ├── site.yml            # entry point
│   ├── inventory/hosts.yml
│   ├── group_vars/all/     # vars.yml committed; vault.yml is not
│   ├── molecule/default/   # container scenario exercised by CI
│   └── roles/
│       ├── base/           # packages, swap, timezone, unattended-upgrades, guest agent
│       ├── user/           # hermes user, keys, sudo, secrets file
│       ├── ssh_hardening/  # sshd_config
│       ├── docker/         # engine, compose, buildx, group membership
│       ├── devtools/       # node, uv, terraform, gh, az, browsers, claude code
│       ├── hermes/         # agent install + gateway systemd unit
│       └── restore/        # rehydrate captured state
├── backup/capture.sh       # capture state from a running host
└── docs/
```

## The target contract

Every root module under `terraform/` outputs the same three values:

| Output | Meaning |
|---|---|
| `host_ip` | address Ansible connects to |
| `ssh_user` | bootstrap user |
| `ssh_private_key_path` | key for that user |

There is also `inventory_yaml`, a ready-made drop-in for
`ansible/inventory/hosts.yml`:

```bash
terraform -chdir=terraform/proxmox output -raw inventory_yaml > ansible/inventory/hosts.yml
```

Adding a target means adding a directory that satisfies that contract. Nothing
in `ansible/` changes.

### Where the targets legitimately differ

The bootstrap user is not the same. Proxmox's cloud-init creates an
unprivileged `ubuntu`; DigitalOcean images give you `root` directly. That is why
`ssh_user` is part of the contract rather than assumed.

The firewall differs too, and for a real reason. On the homelab VLAN the host
has no public address and the UniFi gateway is the boundary, so the Ansible
roles manage no local firewall. A cloud host *does* have a public address, so
`terraform/digitalocean/` defines a provider firewall next to the droplet. The
boundary lives wherever the boundary actually is, rather than being half-applied
in both places.

## Running it

### Terraform — Proxmox

Credentials come from the environment, never from tfvars:

```bash
export PROXMOX_VE_ENDPOINT="https://<host>:8006/api2/json"
export PROXMOX_VE_API_TOKEN="<token-id>=<secret>"
export PROXMOX_VE_INSECURE=true

cd terraform/proxmox
cp terraform.tfvars.example terraform.tfvars   # add your public keys
terraform init && terraform apply
```

The provider also needs SSH to the node itself for operations with no API
equivalent — importing the downloaded image into a VM disk. Point
`proxmox_ssh_private_key_path` at a key authorized for `root` on the node.

Defaults build the homelab host: node `sophron`, VMID 111, `10.20.30.11/24` on
VLAN 7, 8 vCPU / 16 GB / 200 GB.

### Terraform — DigitalOcean

```bash
export DIGITALOCEAN_TOKEN=...
cd terraform/digitalocean
cp terraform.tfvars.example terraform.tfvars   # name your registered SSH keys
terraform init && terraform apply
```

Narrow `ssh_source_addresses` once the host is up. It defaults to the whole
internet only because a fresh droplet has to be reachable to be provisioned.

### Ansible

```bash
ansible-galaxy collection install -r ansible/requirements.yml
ansible-playbook -i ansible/inventory/hosts.yml ansible/site.yml
```

Useful selections:

```bash
# everything except the agent itself
ansible-playbook ... --skip-tags hermes

# just the host policy, no toolchain
ansible-playbook ... --tags base,user,ssh
```

## Three things about this that are not obvious

### The Hermes installer picks its layout from the effective uid

Not from a flag. As root it uses `/usr/local/lib/hermes-agent` with the command
in `/usr/local/bin` — a conventional system-wide install, which the installer
calls its "FHS layout" after the Filesystem Hierarchy Standard. As any other user
it uses `$HERMES_HOME/hermes-agent` with the command in `~/.local/bin`. Both
work. Only one matches this spec.

So `roles/hermes` runs the installer as **root**, with `HERMES_HOME` pointed at
the hermes user's home. Changing it to `become_user: hermes` looks like a
security improvement and is not — the agent already runs unprivileged via the
unit's `User=`, and the change would quietly build a different machine. There is
an assertion in `roles/hermes/tasks/gateway.yml` that fails the run if the unit
is ever set to run as anyone but `hermes`.

### The installer needs its flags; the gateway unit is ours

`install.sh` is genuinely built for unattended use — it detects `curl | bash`
and takes `--non-interactive`, `--skip-setup` and `--skip-browser`. Pass those
and it runs clean. Without them it ends by launching an interactive setup wizard
that blocks forever, because its `(: </dev/tty)` guard does not fire under
Ansible (`become` allocates a pseudo terminal, so a controlling terminal exists).
`--skip-browser` matters separately: the installer would otherwise run its own
`npx playwright install --with-deps` as root, downloading a second copy of the
browsers into `/root/.cache/ms-playwright` that the agent, running as `hermes`,
can never read.

**The gateway unit is templated, not generated.** `hermes gateway install` works,
but it asks "Start the gateway now after installing the service? [Y/n]:" and has
no flag to suppress that. Under Ansible it either blocks or, once the terminal is
removed, takes its default and starts the service — exactly what must not happen
at provision time. Getting it to behave took `setsid`, a stdin redirect, and a
compensating stop task: three mechanisms to dodge one question, for a unit whose
every field is static.

So `roles/hermes/templates/hermes-gateway.service.j2` holds it directly. That is
declarative, idempotent, reviewable in a diff, and states the requirements
(`User=hermes`, system scope, enabled but stopped) instead of asking a CLI to
infer them. The trade is that upstream unit changes no longer arrive for free —
diff the template against what `hermes gateway install --system` generates when
upgrading Hermes.

### The gateway is enabled but not started

Provisioning leaves the unit enabled and stopped. Starting it is a cutover
decision: a fresh host has no credentials, and during a migration the old host
still owns the bot token — two gateways polling one token fight over updates.
Set `hermes_gateway_started: true` when you actually mean it.

## Backup and restore

`backup/capture.sh` runs on the source host and produces one tarball of what
cannot be rebuilt. The `restore` role puts it back.

`restore` is tagged `never`, so a normal run skips it entirely. Provision a host,
prove it clean, *then* lay state on top. It also refuses to overwrite an existing
`state.db` unless `restore_force=true`, because doing so silently discards
conversation history.

See `backup/README.md` for what is and is not captured, and why.

## CI

`.github/workflows/ci.yml` runs the molecule scenario on every pull request and
comments the output back on failure.

The scenario covers `base`, `user`, `ssh_hardening` and `docker` in a container,
and skips anything that pulls a large toolchain over the network or needs a real
VM. That is not a coverage compromise so much as a targeting decision: the
skipped parts are third-party installers, and the covered parts are where host
policy actually lives. Every bug this project has found so far — a missing
`openssh-server`, a service name that does not exist on Debian, and two roles
fighting over group membership — was in the covered half.
