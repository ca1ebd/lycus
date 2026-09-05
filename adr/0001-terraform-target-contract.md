# 0001: Pluggable Terraform targets behind a fixed output contract

Date: 2026-09-05
Status: Accepted

## Context

Lycus began as Ansible with no infrastructure code at all — it could configure a
host but not create one. It needed to build its own host to be a standalone
project rather than a set of roles pointed at whatever someone had lying around.

The immediate destination is a Proxmox VM in a homelab. But the original host was
a DigitalOcean droplet, and the ability to rebuild in the cloud is worth keeping:
it is the disaster-recovery story, and it is the thing that stops the project
quietly becoming homelab-specific.

The alternative placement was to let the homelab repository create the VM and
leave Lycus as configuration-only. That is simpler — one Terraform state against
the Proxmox node instead of two — but it makes Lycus unable to stand up its own
host anywhere, which is the property we actually wanted.

## Decision

Terraform lives in Lycus, as one **root module per target** under
`terraform/<target>/`, each with its own state.

Every target satisfies the same output contract:

| Output | Meaning |
|---|---|
| `host_ip` | address Ansible connects to |
| `ssh_user` | bootstrap user |
| `ssh_private_key_path` | key for that user |

plus `inventory_yaml`, a ready-made Ansible inventory.

Nothing under `ansible/` knows which target ran. Adding a target means adding a
directory, not touching the configuration layer.

`ssh_user` is part of the contract rather than a constant precisely because the
targets genuinely disagree: Proxmox's cloud-init creates an unprivileged
`ubuntu`, while DigitalOcean images hand you `root`.

Two Terraform states now touch the same Proxmox node — this one and the homelab
repository's. They share no resources, so this is fine, but it is a real
constraint: the cloud image filename is namespaced (`lycus-noble-...`) because
two states writing the same filename into the same datastore would fight over it.

## Consequences

The firewall ends up in different places per target, and that is deliberate
rather than an inconsistency to fix. On the homelab VLAN the host has no public
address and the UniFi gateway is the boundary, so no local firewall is managed.
A cloud host does have a public address, so `terraform/digitalocean/` defines a
provider firewall beside the droplet. The boundary is defined where the boundary
actually is, instead of being half-implemented in both layers.

The cost is duplication between target modules — both describe a machine, in
different dialects. A shared module would remove some of it, but the two
providers' resources have little in common beyond the concept, and the contract
is small enough to hold in one's head. Revisit if a third target appears.
