# Architecture rationale

## Why the application is leaving this repository

The first Phoenix service was useful for proving that k3s, Argo CD, ingress, logs,
and metrics worked. Keeping its source and chart in `practice-lab` now works against
the lab's purpose: the cluster needs to deploy several independently built services
for realistic SRE practice.

Separating application repositories from this platform repository makes the ownership
boundary explicit. A service can build and test without owning cluster access, while
the platform repository remains the reviewable source of deployment intent.

## Why ApplicationSets and values remain here

There is one Argo CD instance for the lab. The platform repository therefore owns the
Argo objects that tell that instance what to deploy. Each application gets one
ApplicationSet manifest here, and that manifest renders the application's one chart
with separate staging and prod values files held here.

This is intentionally app-centred rather than environment-centred: a reader looking
for an application's deployment state finds its AppSet and its two values files by
application name. It avoids environment branches, duplicate charts, and a generic
release-file abstraction that mixed Argo metadata with Helm configuration.

## Why artifacts are immutable

Image and chart digests make the deployed bytes explicit and make promotion a desired
state change rather than a rebuild. Staging and production can be compared in a pull
request, rolled back with a revert, and discussed in an interview without hidden CI
or cluster-side mutation.

## Why Vault still results in Kubernetes Secrets

Vault is the authority for secret values and policies; Kubernetes is the runtime API
that most Helm charts and controllers consume. External Secrets Operator bridges the
two using namespace-scoped identities and creates ordinary Kubernetes Secrets at
runtime. This keeps values out of Git while preserving standard Kubernetes behaviour.
Vault Agent Injector is complementary for workloads that need mounted, renewed secret
files rather than a Kubernetes Secret.

## Why the two Vault delivery paths use separate identities

External Secrets and a workload solve different problems, even when both read the
same environment-specific Vault path. The controller receives a dedicated
`vault-secrets` identity solely to materialize standard Kubernetes Secrets. A pod
that needs a renewable file receives a different `vault-workload` identity through
Vault Agent Injector. This makes the audit trail intelligible and avoids binding a
workload to the controller identity. Both identities are scoped by namespace and
environment, and neither overlaps cert-manager's PKI-only roles.

## Why cert-manager and Traefik remain in the ingress path

The lab keeps k3s's Traefik rather than introducing NGINX or a service mesh. It is a
small, standard ingress controller and supports explicit TLS backend validation with
`ServersTransport`. cert-manager requests and renews certificates from Vault PKI:
one for the Traefik listener and a distinct certificate for the Argo Service DNS
names used by Traefik upstream.

The existing Caddy wildcard certificate remains the browser-facing certificate.
Caddy re-encrypts to Traefik over the MB1 TLS relay and validates the Traefik
certificate against the Vault PKI CA. Vault Kubernetes auth gives cert-manager only
the capability to issue its named certificate role through automatically renewed
Kubernetes TokenRequest JWTs. This keeps TLS on every hop without placing any private
key or credential in Git or creating a manually rotated cluster token.
