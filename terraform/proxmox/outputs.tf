# The contract every terraform/<target>/ root module satisfies, so the same
# Ansible inventory can be generated regardless of where the host was built.

output "host_ip" {
  description = "Address Ansible should connect to."
  value       = split("/", var.vm_ipv4_address)[0]
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
            "${var.vm_name}-proxmox" = {
              ansible_host                 = split("/", var.vm_ipv4_address)[0]
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
