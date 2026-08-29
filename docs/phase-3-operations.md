# Phase 3 operations: shared platform services

Argo CD owns the shared add-ons under `k8s/platform/`: Grafana Alloy,
kube-state-metrics, and External Secrets Operator. It does not currently own any
application workload. Applications are onboarded later through one ApplicationSet and
two values files per application.

## Bootstrap Argo CD

From the repository root, using the normal `practice-lab` context:

```sh
helm upgrade --install argocd argo-cd \
  --repo https://argoproj.github.io/argo-helm \
  --version 10.4.1 \
  --namespace argocd \
  --create-namespace \
  --values infra/bootstrap/argocd/values.yaml \
  --wait --timeout 10m

kubectl apply -f infra/bootstrap/argocd/root-application.yaml
kubectl get applications -n argocd
```

## Observability

- Alloy reads Kubernetes container logs and pushes them to the existing Loki service
  at `192.168.4.10:3100`.
- Alloy scrapes kube-state-metrics and remote-writes to Prometheus at
  `192.168.4.10:9090/api/v1/write`.
- Each stream and metric has `cluster="practice-lab"`.

Prometheus remote-write enablement and Caddy DNS routes remain owned by the separate
`home-docker` repository.

## Vault integration next

External Secrets Operator is installed but no Vault role, policy, store, or
ExternalSecret exists yet. Configure Vault Kubernetes authentication first, then add
separate staging and prod service accounts, policies, and namespace-scoped
SecretStores. Install/configure Vault Agent Injector alongside that integration for
workloads that need renewable mounted secrets.

## Verify

```sh
kubectl get applications -n argocd
kubectl get pods -n observability
kubectl get pods -n external-secrets
kubectl get ingress -A
```
