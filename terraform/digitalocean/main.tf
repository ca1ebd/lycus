data "digitalocean_ssh_key" "authorized" {
  for_each = toset(var.ssh_key_names)
  name     = each.value
}

resource "digitalocean_droplet" "lycus" {
  name       = var.droplet_name
  region     = var.region
  size       = var.droplet_size
  image      = var.image
  ssh_keys   = [for k in data.digitalocean_ssh_key.authorized : k.id]
  backups    = var.enable_backups
  monitoring = var.enable_monitoring
  tags       = var.tags

  lifecycle {
    # A change to the image slug would destroy and recreate the droplet,
    # taking the agent's state with it. Rebuilds are deliberate: taint it.
    ignore_changes = [image]
  }
}

# Unlike the Proxmox target, this host has a public address. The Ansible roles
# deliberately do not manage ufw, so the boundary has to exist here instead.
resource "digitalocean_firewall" "lycus" {
  name        = "${var.droplet_name}-fw"
  droplet_ids = [digitalocean_droplet.lycus.id]

  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = var.ssh_source_addresses
  }

  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}
