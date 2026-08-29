data "libvirt_domain_interface_addresses" "control_plane" {
  domain     = libvirt_domain.control_plane.name
  source     = "lease"
  depends_on = [libvirt_domain.control_plane]
}

locals {
  control_plane_ipv4_addresses = flatten([
    for interface in data.libvirt_domain_interface_addresses.control_plane.interfaces : [
      for address in interface.addrs : address.addr if address.type == "ipv4"
    ]
  ])
}

output "control_plane_name" {
  description = "The libvirt domain name for the initial k3s server."
  value       = libvirt_domain.control_plane.name
}

output "control_plane_ip" {
  description = "The DHCP-assigned IPv4 address used by Ansible and SSH."
  value       = one(local.control_plane_ipv4_addresses)
}

output "control_plane_ssh_command" {
  description = "Repository-owned SSH wrapper for the generated Ansible user from the Mac."
  value       = "./scripts/connect-control-plane.sh"
}
