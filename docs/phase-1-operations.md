# Phase 1: VM Provisioning

Phase 1 creates only `practice-cp-1`: a 2-vCPU, 4-GiB, 30-GiB ARM64 Ubuntu
24.04 VM. It uses the pre-existing libvirt `default` NAT network on MB1. Terraform
does not create, modify, or adopt that network. The committed bootstrap script defines
the conventional `default` network and image pool when MB1 has not registered them.

The Mac is the Terraform and Ansible control machine. Terraform connects to MB1 using
`qemu+sshcmd://bcant@mb1.opsguy.io/system`. This transport delegates host-key handling
to the Mac's verified SSH client. The VM receives a DHCP lease from libvirt;
Terraform exposes that address and `make inventory` generates the ignored Ansible
inventory with an SSH jump through MB1.

## Image verification

The image download script retrieves Ubuntu's official `SHA256SUMS` manifest from the
same Noble `current` directory, then validates the ARM64 cloud image against that
manifest before it is used. The verified hash is printed at completion. The image is
stored in ignored `artifacts/images/` and is not committed.

## Commands

```sh
make bootstrap
make init
make image
make terraform-validate
make plan
make apply
make plan       # should show no changes
make inventory
ANSIBLE_CONFIG=infrastructure/ansible/ansible.cfg ansible all -m ping
```

The destroy command is intentional and destructive:

```sh
make destroy
```

Run it only after confirming `practice-cp-1` is the target. It removes only resources
recorded in the local Terraform state; it does not touch MB1's Docker Swarm workloads
or the shared libvirt defaults. To remove the entire lab bootstrap after Terraform has
removed every VM and volume, run:

```sh
make destroy-all
```

`bootstrap-libvirt.sh destroy` refuses to undefine the default network or pool if any
libvirt domain or volume remains, and never removes `/var/lib/libvirt/images`.

The `bootstrap-cleanup-session` target is a one-time repair for an inactive user-session
network accidentally created by an early bootstrap script. It is not part of normal
setup or teardown.
