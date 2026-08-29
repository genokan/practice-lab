# Phase 3 operations: Argo CD and light observability

Argo CD owns the cluster add-ons and initial environment workloads in `platform/` and
`charts/`. The root application installs Grafana Alloy, kube-state-metrics, External
Secrets Operator, and one small `hello` deployment in each environment. The existing
homelab Prometheus, Loki, and Grafana remain the only observability backends.

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

## Initial staging and production deployments

`hello-api-delivery` owns an ApplicationSet that generates staging and production
applications from explicitly named release manifests. Each generated application pulls
the Helm OCI chart and container image by immutable digest. The release manifests
create and use the `hello-staging` and `hello-production` namespaces respectively.
The first production image remains a small, version-pinned public nginx image solely
to preserve the known-good GitOps baseline until the Phoenix service is promoted.

The staging release manifest enables a standard `Ingress` named `hello-staging.opsguy.io`. The
root application also owns the `argo.opsguy.io` Ingress for the Argo CD UI. MB1
proxies one LAN port to k3s Traefik; Caddy on pi5 terminates TLS and proxies those
hostnames to MB1. The Argo Ingress keeps TLS enabled between Traefik and
`argocd-server`. Future browser-facing services add an Ingress and Caddy hostname,
not another MB1 relay.

Staging uses the Phoenix image by digest; production intentionally remains on the
baseline until a promotion copies that exact image digest without rebuilding it.
Chart digests are selected independently, so a chart template change reaches
production only when the production release manifest is explicitly updated.

External Secrets Operator is installed now, but no Vault role, policy, `SecretStore`,
or `ExternalSecret` is created yet: the nginx baseline does not consume a secret.
Those resources require an authenticated Vault administration step and will be added
with the first real application secret. The intended design remains two namespace
scoped stores with separate staging and production Vault identities.

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
kubectl get pods -n hello-staging
kubectl get pods -n hello-production
kubectl get pods -n external-secrets
```

In Grafana, filter logs with `{cluster="practice-lab"}`. Query a lightweight status
metric such as `kube_pod_status_phase{cluster="practice-lab"}` in Prometheus.
