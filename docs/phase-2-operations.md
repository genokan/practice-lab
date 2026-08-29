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
`kubeconfig/practice-lab.yaml` path. MB1 exposes the API at
`https://mb1.opsguy.io:6443`.

## Use kubectl normally

The Ansible bootstrap writes the ignored source kubeconfig under `kubeconfig/` and the
normal Mac kubeconfig has the `practice-lab` context. Use ordinary Kubernetes commands
without a wrapper or a per-command environment variable:

```sh
kubectl config use-context practice-lab
kubectl get nodes
kubectl get pods -A
```

## Verify the cluster

```sh
kubectl get nodes
kubectl get deployments -n kube-system
kubectl run phase2-connectivity --image=busybox:1.37.0 --restart=Never --command -- sh -ec 'nslookup kubernetes.default.svc.cluster.local && wget -qO- https://example.com >/dev/null'
kubectl wait --for=jsonpath='{.status.phase}'=Succeeded pod/phase2-connectivity --timeout=120s
kubectl delete pod phase2-connectivity
```

## Re-run behavior

`make k3s` is safe to repeat. It retains the pinned k3s version, rewrites only managed
configuration when necessary, and refreshes the ignored local kubeconfig.
