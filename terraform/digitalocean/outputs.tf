# Same contract as terraform/proxmox/, so either target feeds the same inventory.

output "host_ip" {
  description = "Address Ansible should connect to."
  value       = digitalocean_droplet.lycus.ipv4_address
}

output "ssh_user" {
  description = "Bootstrap user for Ansible."
  value       = var.ssh_user
}

output "ssh_private_key_path" {
  description = "Private key for the bootstrap user."
  value       = var.ssh_private_key_path
}

output "inventory_yaml" {
  description = "Drop-in replacement for ansible/inventory/hosts.yml."
  value = yamlencode({
    all = {
      children = {
        lycus = {
          hosts = {
            "${var.droplet_name}-digitalocean" = {
              ansible_host                 = digitalocean_droplet.lycus.ipv4_address
              ansible_user                 = var.ssh_user
              ansible_ssh_private_key_file = var.ssh_private_key_path
            }
          }
          vars = {
            ansible_python_interpreter = "/usr/bin/python3"
          }
        }
      }
    }
  })
}
