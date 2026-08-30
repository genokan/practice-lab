# Phase 3 operations: shared platform services

Argo CD owns the shared add-ons under `k8s/platform/`: Grafana Alloy,
kube-state-metrics, and External Secrets Operator. It also owns the ApplicationSets
under `k8s/apps/`; `hello-api` is the reference application.

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

The lab uses a 15-second reconciliation poll with no jitter so GitOps merges are
noticed promptly without exposing an inbound GitHub webhook. After changing those
Argo CD settings, restart the application controller and repo server:

```sh
kubectl -n argocd rollout restart statefulset/argocd-application-controller
kubectl -n argocd rollout restart deployment/argocd-repo-server
```

## Argo CD access

`argo.opsguy.io` requires TLS on every hop:

```text
browser -> Caddy -> MB1 relay -> Traefik -> argocd-server
          TLS       TLS relay    TLS       validated TLS
```

The existing Caddy wildcard certificate protects the browser edge. It does not solve
Traefik's current HTTPS connection to `argocd-server`: Argo generated a self-signed
certificate and Traefik dials pod endpoints, so the endpoint IP does not match the
certificate SAN.

The implementation is deliberately certificate-manager and Vault-PKI based:

1. Install cert-manager as an Argo-managed platform component.
2. Configure Vault's `practice-lab-pki` PKI engine and its
   `kubernetes-practice-lab` auth mount. Each cert-manager role can issue only its
   named Argo certificate role; it cannot read KV secrets or administer Vault.
   cert-manager requests short-lived Kubernetes TokenRequest JWTs automatically, so
   neither a Vault token nor a static TokenReview JWT is stored for the cluster.
3. Create separate Vault-issued Certificates for the Traefik listener
   (`argo.opsguy.io`) and Argo's stable Service DNS names. Argo uses
   `argocd-server-tls` for its HTTPS endpoint. During initial bootstrap, restart
   `argocd-server` after this Secret is first issued so it leaves its generated
   self-signed certificate behind.
4. Configure the Traefik listener to use `argocd-ingress-tls`. Its backend Service
   (not the Ingress) selects HTTPS and a `ServersTransport` with
   `serverName: argocd-server.argocd.svc.cluster.local` for the HTTPS backend.
   Traefik verifies the Vault CA chain and hostname; it must not use
   `insecureSkipVerify`.
5. Change the MB1 TCP relay to forward a TLS port to Traefik’s HTTPS entrypoint, and
   make Caddy use an HTTPS upstream with normal certificate verification against the
   Vault PKI CA.

The Vault policy names and relay port are versioned with this implementation. No
certificate key, Vault token, or Vault value is committed to either repository.

After initial issuance, run this one-time reload before validating the route:

```sh
kubectl rollout restart deployment/argocd-server -n argocd
kubectl rollout status deployment/argocd-server -n argocd --timeout=180s
```

### Vault bootstrap

After Argo has synced the `cert-manager` and `tls` Applications, run the tracked
bootstrap once with a Vault operator token:

```sh
export VAULT_TOKEN=<operator-token>
INSTALL_CADDY_CA=1 ./infra/scripts/configure-vault-pki.sh
```

`VAULT_ADDR` may point at a local SSH tunnel for administration. In that case set
`VAULT_PUBLIC_ADDR=https://vault.opsguy.io` so issued certificates retain the stable
public issuing-CA and CRL URLs.

The script creates only the `practice-lab-pki` PKI mount, its two named signing roles,
the `kubernetes-practice-lab` auth mount, and the two cert-manager policies/roles. It
does not create a cluster Vault token or static TokenReview token. It also writes the
public CA certificate into Caddy's existing certificate mount so Caddy can validate
its TLS upstream. The Caddyfile change and MB1 TLS relay are versioned separately and
must be deployed before switching `argo.opsguy.io` to the TLS relay.

## Observability

- Alloy reads Kubernetes container logs and pushes them to the existing Loki service
  at `192.168.4.10:3100`.
- Alloy scrapes kube-state-metrics and remote-writes to Prometheus at
  `192.168.4.10:9090/api/v1/write`.
- Each stream and metric has `cluster="practice-lab"`.

Prometheus remote-write enablement and Caddy DNS routes remain owned by the separate
`home-docker` repository.

## Workload Vault integration

External Secrets Operator now uses separate staging and production Vault roles and
namespace-scoped SecretStores. Vault Agent Injector is also installed as a shared
platform capability. See [Phase 5 operations](phase-5-operations.md) for the exact
paths, identities, enrollment patterns, and verification commands.

## Verify

```sh
kubectl get applications -n argocd
kubectl get pods -n observability
kubectl get pods -n external-secrets
kubectl get ingress -A
```
