# Phase 2 operations: Ansible and k3s

Phase 2 configures the existing `practice-cp-1` VM with a pinned, single-node k3s
server. Terraform continues to own the VM; Ansible owns the guest configuration.

## Run the configuration

From the repository root:

```sh
make ansible-syntax
make k3s
```

The playbook installs `v1.36.1+k3s1`, writes `/etc/rancher/k3s/config.yaml`, enables
the `k3s` service, and fetches its kubeconfig to the ignored
`kubeconfig/practice-lab.yaml` path.

## Use kubectl from the Mac

The standard libvirt network is NAT-only, so the Mac has no direct route to the VM
address. The repository wrapper opens a temporary SSH tunnel through MB1 for each
command, then closes it when the command exits:

```sh
./scripts/kubectl-practice-lab.sh get nodes
make kubectl-node
```

This preserves the simple default libvirt network and does not add a permanent local
tunnel. The bootstrap-owned `DOCKER-USER` egress rules are documented in the Phase 1
operations guide.

## Verify the cluster

```sh
make verify-k3s
```

The verification checks the Ready node, CoreDNS, Traefik, metrics-server, and
local-path-provisioner rollouts, then runs an ephemeral pod that resolves cluster DNS
and reaches the public internet. The test pod is removed when the script exits.

## Re-run behavior

`make k3s` is safe to repeat. It retains the pinned k3s version, rewrites only managed
configuration when necessary, and refreshes the ignored local kubeconfig.
