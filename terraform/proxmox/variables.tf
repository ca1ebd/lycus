variable "proxmox_node" {
  description = "Proxmox node name to place the VM on."
  type        = string
  default     = "sophron"
}

variable "proxmox_ssh_user" {
  description = "SSH user on the Proxmox node. Needs to run qm/pvesm, so root in practice."
  type        = string
  default     = "root"
}

variable "proxmox_ssh_private_key_path" {
  description = "Path to the private key authorized for proxmox_ssh_user on the node."
  type        = string
  default     = "../../secrets/proxmox_host_key"
}

variable "vm_id" {
  description = "Proxmox VMID."
  type        = number
  default     = 111
}

variable "vm_name" {
  description = "VM name in Proxmox."
  type        = string
  default     = "lycus"
}

variable "vm_cores" {
  description = "vCPU cores. The node is a 32-thread i9-13900E, so this is not tight."
  type        = number
  default     = 8
}

variable "vm_memory_mb" {
  description = "RAM in MB. The old droplet had 3.8 GB and swapped."
  type        = number
  default     = 16384
}

variable "vm_disk_gb" {
  description = "Root disk in GB. The old droplet's 48 GB sat at 95% full."
  type        = number
  default     = 200
}

variable "vm_datastore" {
  description = "Datastore for the VM disk and cloud-init drive."
  type        = string
  default     = "local-lvm"
}

variable "image_datastore" {
  description = "Datastore that holds the downloaded cloud image."
  type        = string
  default     = "local"
}

variable "vm_ipv4_address" {
  description = "Static address in CIDR form. DHCP is disabled on this VLAN."
  type        = string
  default     = "10.20.30.11/24"
}

variable "vm_ipv4_gateway" {
  description = "Default gateway for the homelab VLAN."
  type        = string
  default     = "10.20.30.1"
}

variable "vm_vlan_id" {
  description = "VLAN tag. Without this the guest lands on the untagged native network (the main LAN), not the homelab one."
  type        = number
  default     = 7
}

variable "vm_bridge" {
  description = "Proxmox bridge to attach to."
  type        = string
  default     = "vmbr0"
}

variable "ssh_user" {
  description = "Bootstrap user created by cloud-init, used by Ansible."
  type        = string
  default     = "ubuntu"
}

variable "ssh_public_keys" {
  description = "Public keys authorized for the bootstrap user."
  type        = list(string)
}

variable "ssh_private_key_path" {
  description = "Path to the matching private key, emitted for the Ansible inventory."
  type        = string
  default     = "~/.ssh/lycus_vm_key"
}

variable "cloud_image_url" {
  description = <<-EOT
    Ubuntu cloud image to import. 26.04 LTS ("resolute"), the current LTS.
    The Ansible roles target this release: apt repository names and the 24.04
    t64 package names both carry forward, so 24.04 also works if pinned back.
  EOT
  type        = string
  default     = "https://cloud-images.ubuntu.com/resolute/current/resolute-server-cloudimg-amd64.img"
}

variable "cloud_image_file_name" {
  description = <<-EOT
    Filename for the downloaded image in image_datastore. Deliberately namespaced
    to this project: two Terraform states writing the same filename into the same
    datastore would fight over it, and the homelab repo has its own config
    against the same node.
  EOT
  type        = string
  default     = "lycus-resolute-server-cloudimg-amd64.qcow2"
}

variable "vm_agent_enabled" {
  description = <<-EOT
    Whether the guest agent channel is attached. This is not just a "wait for the
    agent" switch: it controls whether Proxmox gives the VM the VirtIO serial
    device at /dev/virtio-ports/org.qemu.guest_agent.0. With it false, the guest's
    qemu-guest-agent.service has no device to bind and cannot start at all, so
    installing the package accomplishes nothing.

    So it defaults true, and vm_agent_timeout bounds the wait instead. Note the
    device only appears after a full power cycle — changing this on a running VM
    needs a stop/start, not a reboot.
  EOT
  type        = bool
  default     = true
}

variable "vm_agent_timeout" {
  description = <<-EOT
    How long Terraform waits for the guest agent. The provider default is 15m,
    which is where the "every apply hangs for a quarter of an hour" behaviour
    comes from: the stock cloud image has no agent until Ansible installs one, so
    the first apply always waits out the full timeout. Addresses here are static,
    so nothing actually depends on the agent reporting them.
  EOT
  type        = string
  default     = "2m"
}

variable "vm_dns_servers" {
  description = "Resolvers for the guest. DHCP is disabled on this VLAN, so nothing supplies these automatically."
  type        = list(string)
  default     = ["10.20.30.1", "1.1.1.1"]
}
