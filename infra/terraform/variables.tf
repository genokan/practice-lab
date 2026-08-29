variable "libvirt_uri" {
  description = "Remote libvirt system URI for the MB1 virtualization host."
  type        = string
  default     = "qemu+sshcmd://bcant@mb1.opsguy.io/system"
}

variable "storage_pool" {
  description = "Existing libvirt storage pool used for practice-lab volumes."
  type        = string
  default     = "default"
}

variable "network_name" {
  description = "Existing libvirt NAT network used by the practice control plane."
  type        = string
  default     = "default"
}

variable "control_plane_name" {
  description = "Libvirt domain and guest hostname for the initial k3s server."
  type        = string
  default     = "practice-cp-1"
}

variable "control_plane_vcpus" {
  description = "vCPU count for the initial control-plane VM."
  type        = number
  default     = 2
}

variable "control_plane_memory_mib" {
  description = "Memory in MiB for the initial control-plane VM."
  type        = number
  default     = 4096
}

variable "control_plane_disk_gib" {
  description = "Root-disk capacity in GiB for the initial control-plane VM."
  type        = number
  default     = 30
}

variable "control_plane_mac" {
  description = "Stable MAC address used to discover the DHCP lease on libvirt default."
  type        = string
  default     = "52:54:00:12:23:10"
}

variable "ssh_public_key_path" {
  description = "Local public key authorized for the Ansible user through cloud-init."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}
