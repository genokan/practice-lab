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

MB1's Docker rules set a host-wide `FORWARD` drop policy, which otherwise prevents
the standard libvirt NAT network from reaching the internet. `make bootstrap` uses
Docker's intended `DOCKER-USER` extension chain for guest egress and exposes the k3s
API as `mb1.opsguy.io:6443` with a systemd TCP proxy. These are persistent, removed
by `make destroy-all`, and do not create a second network or change Swarm workload
rules.

## Image verification

The image download script retrieves Ubuntu's official `SHA256SUMS` manifest from the
same Noble `current` directory, then validates the ARM64 cloud image against that
manifest before it is used. The verified hash is stored beside the ignored image cache
and printed at completion. A normal `make image` verifies and reuses that cache. Run
`make image-refresh` only when intentionally accepting the then-current Ubuntu image.

## Commands

```sh
make bootstrap
make init
make image-refresh  # first download, or deliberate Ubuntu image refresh
make image          # later runs verify and reuse the cache
make terraform-validate
make plan
make apply
make plan       # should show no changes
make inventory
./infra/scripts/connect-control-plane.sh hostname
ANSIBLE_CONFIG=infra/ansible/ansible.cfg ansible all -m ping
```

The SSH wrapper and generated inventory use an ignored, project-local known-hosts file
under `artifacts/ssh/`. The first connection records the VM's generated host key there;
the global Mac SSH configuration remains unchanged.

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
