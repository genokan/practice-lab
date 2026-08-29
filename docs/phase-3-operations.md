# Phase 3 operations: Argo CD and light observability

Argo CD owns the cluster add-ons in `platform/`. The initial root application installs
Grafana Alloy and kube-state-metrics. The existing homelab Prometheus, Loki, and
Grafana remain the only observability backends.

## Bootstrap Argo CD

From the repository root, using the normal default kubeconfig:

```sh
helm upgrade --install argocd argo-cd \
  --repo https://argoproj.github.io/argo-helm \
  --version 10.4.1 \
  --namespace argocd \
  --create-namespace \
  --values bootstrap/argocd/values.yaml \
  --wait --timeout 10m

kubectl apply -f bootstrap/argocd/root-application.yaml
kubectl get applications -n argocd
```

## What observability sends

- Alloy reads Kubernetes container logs and writes them to Loki at `192.168.4.10:3100`.
- Alloy scrapes kube-state-metrics and remote-writes to Prometheus at
  `192.168.4.10:9090/api/v1/write`.
- Every emitted stream/series has `cluster="practice-lab"`. Log streams also carry
  `namespace`, `pod`, and `container` labels.

Prometheus must have its remote-write receiver enabled in the separately versioned
`home-docker` configuration. Neither endpoint contains credentials, and neither is
stored as a secret in this repository.

## Verify

```sh
kubectl get applications -n argocd
kubectl get pods -n observability
```

In Grafana, filter logs with `{cluster="practice-lab"}`. Query a lightweight status
metric such as `kube_pod_status_phase{cluster="practice-lab"}` in Prometheus.
