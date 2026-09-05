variable "droplet_name" {
  description = "Droplet name."
  type        = string
  default     = "lycus"
}

variable "region" {
  description = "DigitalOcean region slug."
  type        = string
  default     = "nyc3"
}

variable "droplet_size" {
  description = <<-EOT
    Size slug. The default is 4 vCPU / 8 GB — smaller than the Proxmox target,
    because on rented hardware this is a cost decision rather than a free one.
    The original droplet was 2 vCPU / 4 GB and had to run with swap to survive
    OOM kills, so do not go below this.
  EOT
  type        = string
  default     = "s-4vcpu-8gb"
}

variable "image" {
  description = "Base image. Must match what the Ansible roles target."
  type        = string
  default     = "ubuntu-24-04-x64"
}

variable "ssh_key_names" {
  description = "Names of SSH keys already registered in the DigitalOcean account."
  type        = list(string)
}

variable "ssh_user" {
  description = <<-EOT
    Bootstrap user for Ansible. DigitalOcean images give you root directly, with
    no unprivileged bootstrap account — unlike the Proxmox target, where
    cloud-init creates one.
  EOT
  type        = string
  default     = "root"
}

variable "ssh_private_key_path" {
  description = "Private key matching ssh_key_names, emitted for the Ansible inventory."
  type        = string
  default     = "~/.ssh/lycus_vm_key"
}

variable "enable_backups" {
  description = "DigitalOcean's own snapshot backups. Independent of backup/capture.sh, which captures agent state rather than whole disks."
  type        = bool
  default     = true
}

variable "enable_monitoring" {
  description = "DigitalOcean's monitoring agent."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Droplet tags."
  type        = list(string)
  default     = ["lycus", "terraform"]
}

variable "ssh_source_addresses" {
  description = <<-EOT
    Who may reach SSH. Defaults to the whole internet because a fresh droplet has
    to be reachable to be provisioned at all, but narrow this to known addresses
    as soon as the host is up. The original droplet ran with no host firewall and
    no cloud firewall at all, which is how a print server ended up listening on
    its public address.
  EOT
  type        = list(string)
  default     = ["0.0.0.0/0", "::/0"]
}
