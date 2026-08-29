<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | = 1.16.0 |
| <a name="requirement_libvirt"></a> [libvirt](#requirement\_libvirt) | = 0.9.8 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_libvirt"></a> [libvirt](#provider\_libvirt) | 0.9.8 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [libvirt_cloudinit_disk.control_plane](https://registry.terraform.io/providers/dmacvicar/libvirt/0.9.8/docs/resources/cloudinit_disk) | resource |
| [libvirt_domain.control_plane](https://registry.terraform.io/providers/dmacvicar/libvirt/0.9.8/docs/resources/domain) | resource |
| [libvirt_volume.control_plane_cloud_init](https://registry.terraform.io/providers/dmacvicar/libvirt/0.9.8/docs/resources/volume) | resource |
| [libvirt_volume.control_plane_root](https://registry.terraform.io/providers/dmacvicar/libvirt/0.9.8/docs/resources/volume) | resource |
| [libvirt_volume.ubuntu_noble_arm64](https://registry.terraform.io/providers/dmacvicar/libvirt/0.9.8/docs/resources/volume) | resource |
| [libvirt_domain_interface_addresses.control_plane](https://registry.terraform.io/providers/dmacvicar/libvirt/0.9.8/docs/data-sources/domain_interface_addresses) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_control_plane_disk_gib"></a> [control\_plane\_disk\_gib](#input\_control\_plane\_disk\_gib) | Root-disk capacity in GiB for the initial control-plane VM. | `number` | `30` | no |
| <a name="input_control_plane_mac"></a> [control\_plane\_mac](#input\_control\_plane\_mac) | Stable MAC address used to discover the DHCP lease on libvirt default. | `string` | `"52:54:00:12:23:10"` | no |
| <a name="input_control_plane_memory_mib"></a> [control\_plane\_memory\_mib](#input\_control\_plane\_memory\_mib) | Memory in MiB for the initial control-plane VM. | `number` | `4096` | no |
| <a name="input_control_plane_name"></a> [control\_plane\_name](#input\_control\_plane\_name) | Libvirt domain and guest hostname for the initial k3s server. | `string` | `"practice-cp-1"` | no |
| <a name="input_control_plane_vcpus"></a> [control\_plane\_vcpus](#input\_control\_plane\_vcpus) | vCPU count for the initial control-plane VM. | `number` | `2` | no |
| <a name="input_libvirt_uri"></a> [libvirt\_uri](#input\_libvirt\_uri) | Remote libvirt system URI for the MB1 virtualization host. | `string` | `"qemu+sshcmd://bcant@mb1.opsguy.io/system"` | no |
| <a name="input_network_name"></a> [network\_name](#input\_network\_name) | Existing libvirt NAT network used by the practice control plane. | `string` | `"default"` | no |
| <a name="input_ssh_public_key_path"></a> [ssh\_public\_key\_path](#input\_ssh\_public\_key\_path) | Local public key authorized for the Ansible user through cloud-init. | `string` | `"~/.ssh/id_ed25519.pub"` | no |
| <a name="input_storage_pool"></a> [storage\_pool](#input\_storage\_pool) | Existing libvirt storage pool used for practice-lab volumes. | `string` | `"default"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_control_plane_ip"></a> [control\_plane\_ip](#output\_control\_plane\_ip) | The DHCP-assigned IPv4 address used by Ansible and SSH. |
| <a name="output_control_plane_name"></a> [control\_plane\_name](#output\_control\_plane\_name) | The libvirt domain name for the initial k3s server. |
| <a name="output_control_plane_ssh_command"></a> [control\_plane\_ssh\_command](#output\_control\_plane\_ssh\_command) | Repository-owned SSH wrapper for the generated Ansible user from the Mac. |
<!-- END_TF_DOCS -->