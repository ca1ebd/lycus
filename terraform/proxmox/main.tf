resource "proxmox_download_file" "ubuntu_cloud_image" {
  content_type = "import"
  datastore_id = var.image_datastore
  node_name    = var.proxmox_node
  url          = var.cloud_image_url
  file_name    = var.cloud_image_file_name
}

resource "proxmox_virtual_environment_vm" "lycus" {
  vm_id       = var.vm_id
  name        = var.vm_name
  node_name   = var.proxmox_node
  description = "Hermes Agent host. Built by the lycus repo: terraform/proxmox + ansible/site.yml."
  tags        = ["lycus", "terraform"]
  started     = true

  # enabled controls whether the VirtIO serial device exists at all, so the
  # guest's qemu-guest-agent has something to bind to. timeout bounds the wait
  # for a guest that has not installed the agent yet. See variables.tf.
  agent {
    enabled = var.vm_agent_enabled
    timeout = var.vm_agent_timeout
  }

  cpu {
    cores = var.vm_cores
    # Pass through the host's instruction set. This is a homelab node with no
    # live migration to a different CPU, so there is nothing to stay portable for.
    type = "host"
  }

  memory {
    dedicated = var.vm_memory_mb
  }

  disk {
    datastore_id = var.vm_datastore
    file_id      = proxmox_download_file.ubuntu_cloud_image.id
    interface    = "scsi0"
    size         = var.vm_disk_gb
    iothread     = true
    discard      = "on"
  }

  network_device {
    bridge  = var.vm_bridge
    vlan_id = var.vm_vlan_id
  }

  operating_system {
    type = "l26"
  }

  initialization {
    datastore_id = var.vm_datastore

    ip_config {
      ipv4 {
        address = var.vm_ipv4_address
        gateway = var.vm_ipv4_gateway
      }
    }

    # DHCP is disabled on this VLAN, so nothing hands out resolvers either.
    dns {
      servers = var.vm_dns_servers
    }

    user_account {
      username = var.ssh_user
      keys     = var.ssh_public_keys
    }
  }

  lifecycle {
    # The cloud image is only ever the *initial* contents of the disk. Once the
    # host is built and holding the agent's state, a new image release must not
    # silently trigger a disk replacement.
    ignore_changes = [disk[0].file_id]
  }
}
