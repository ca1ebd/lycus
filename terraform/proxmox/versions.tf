terraform {
  required_version = ">= 1.5"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.66"
    }
  }
}

# Credentials come from the environment, not from tfvars:
#   PROXMOX_VE_ENDPOINT, PROXMOX_VE_API_TOKEN, PROXMOX_VE_INSECURE
#
# The provider also needs SSH to the node for operations with no API equivalent
# (importing a downloaded disk image into a VM disk).
provider "proxmox" {
  ssh {
    agent       = false
    username    = var.proxmox_ssh_user
    private_key = file(var.proxmox_ssh_private_key_path)
  }
}
