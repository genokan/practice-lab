# Phase 5 operations: workload Vault integration

Phase 5 adds two standard ways for workloads to consume values kept in Vault. Vault
remains the authority; no secret value is committed to this repository.

- **External Secrets Operator** is the normal choice for a chart that consumes an
  ordinary Kubernetes Secret. It authenticates through the namespace-scoped
  `SecretStore` named `vault` and materializes a native Secret at runtime.
- **Vault Agent Injector** is available for workloads that need a mounted,
  renewable file. It uses a dedicated workload ServiceAccount and pod annotations to
  render files below `/vault/secrets`.

## Boundary and paths

The empty KV v2 mount is `practice-lab-kv`. It has two disjoint paths:

```text
practice-lab-kv/staging/<application>
practice-lab-kv/prod/<application>
```

Each environment has separate read-only policies and four distinct Kubernetes auth
roles in the existing `kubernetes-practice-lab` auth mount:

| Purpose | Staging role | Production role | Kubernetes identity |
| --- | --- | --- | --- |
| External Secrets | `eso-staging` | `eso-prod` | `vault-secrets` in its namespace |
| Vault Agent | `workload-staging` | `workload-prod` | `vault-workload` in its namespace |

The cert-manager roles remain certificate-issuance-only and cannot read these KV
paths. Staging cannot read production and vice versa.

## One-time Vault configuration

After the tracked Kubernetes resources have been merged, run this from the repository
root with a Vault operator token:

```sh
export VAULT_TOKEN=<operator-token>
./infra/scripts/configure-vault-workloads.sh
```

The script creates no secret values. Add a real value with Vault directly, for
example `vault kv put practice-lab-kv/staging/<application> key=value`; keep the
value out of shell history when it is sensitive.

## External Secrets enrollment

Create an `ExternalSecret` in the application's namespace that references the local
`vault` SecretStore. The following has no inline secret value and produces the
standard Kubernetes Secret expected by a Helm chart:

```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: hello-runtime
  namespace: hello-staging
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault
    kind: SecretStore
  target:
    name: hello-runtime
    creationPolicy: Owner
  data:
    - secretKey: database-url
      remoteRef:
        key: staging/hello-api
        property: database-url
```

The application values then reference `hello-runtime` and `database-url`; they never
contain the database URL itself.

## Vault Agent enrollment

An application chart must select its environment's `vault-workload` ServiceAccount.
Then its Pod template may use annotations such as:

```yaml
vault.hashicorp.com/agent-inject: "true"
vault.hashicorp.com/auth-path: auth/kubernetes-practice-lab
vault.hashicorp.com/role: workload-staging
vault.hashicorp.com/agent-inject-secret-runtime: practice-lab-kv/data/staging/hello-api
```

The injector connects to `https://vault.opsguy.io` with TLS verification enabled. Do
not use `vault.hashicorp.com/tls-skip-verify`. The reference application has not been
opted into the injector yet; Phase 5 establishes the platform capability and the
separate identity it will use.

## Verify

```sh
kubectl get applications -n argocd vault vault-agent-injector
kubectl get pods -n vault
kubectl get serviceaccounts,secretstores -n hello-staging
kubectl get serviceaccounts,secretstores -n hello-prod
kubectl describe secretstore vault -n hello-staging
kubectl describe secretstore vault -n hello-prod
```

Both SecretStores should report `Valid`. An `ExternalSecret` should report `SecretSynced`
only after its corresponding Vault value exists.
