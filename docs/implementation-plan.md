# Practice Lab Implementation Plan

## 1. Purpose

Build a small, reproducible environment for practicing SRE interview tasks involving:

- Terraform and libvirt
- Ansible and Linux configuration
- k3s and standard Kubernetes troubleshooting with `kubectl`
- Helm chart authoring and debugging
- Argo CD and pull-based GitOps
- GitHub Actions validation, caching, image builds, and promotion
- An Elixir/Phoenix application with a PostgreSQL dependency
- Metrics and logs sent to the existing homelab Prometheus, Loki, and Grafana stack

This is a practice system, not a new production homelab. Optimize for fast rebuilds,
clear ownership boundaries, and realistic failure injection. Do not copy the full
complexity of the legacy `homelab` repository.

## 2. Existing Environment and Constraints

- Primary workstation: Mac with Git, `kubectl`, Helm, and the Argo CD CLI.
- Virtualization host: `mb1`, an Apple Silicon MacBook Pro running Fedora Linux.
- `mb1` currently participates in the Docker Swarm managed by `home-docker`.
- Existing observability backends run on `pi5-1` at `192.168.4.10`:
  - Prometheus: port `9090`
  - Loki: port `3100`
  - Grafana: port `3000`, also available through the existing Caddy configuration
- An existing HashiCorp Vault instance is available at `https://vault.opsguy.io` and
  is the authoritative source for lab secrets.
- The new `practice-lab` repository is public.
- GitHub must not require inbound access to the homelab.
- Do not commit credentials, Terraform state, kubeconfig, k3s tokens, database URLs,
  Argo credentials, or generated secrets.
- Do not disrupt the Docker Swarm workloads already running on `mb1`.

## 3. Target Architecture

```text
Primary Mac
├── Terraform client
├── Ansible client
├── kubectl / Helm / argocd
└── local secrets and generated state (gitignored)
          │
          │ SSH / libvirt API over the LAN
          ▼
mb1 (Fedora ARM64)
├── existing Docker Swarm workloads (out of scope)
└── libvirt/KVM
    ├── practice-cp-1       k3s server/control plane
    ├── practice-worker-1   optional k3s agent
    └── practice-worker-2   optional k3s agent

GitHub
├── repository and pull requests
├── GitHub Actions validation/builds
└── GHCR application images
          ▲                       ▲
          │ outbound Git pull     │ outbound image pull
          │                       │
Argo CD in k3s                containerd in k3s

Vault on pi5-1
└── environment-scoped secrets ──> External Secrets in k3s

k3s Grafana Alloy
├── metrics ──remote write──> Prometheus on pi5-1
└── logs ─────────push───────> Loki on pi5-1
```

### Trust boundary

GitHub Actions validates code, builds images, publishes to GHCR, and modifies desired
state through Git. It does not receive kubeconfig or credentials for `mb1`.

Argo CD and containerd initiate outbound connections to GitHub and GHCR. Terraform,
Ansible, and the initial Argo bootstrap are run from the trusted local workstation.
No GitHub webhook or publicly exposed Argo API is required.

## 4. Cluster Shape

Terraform must expose a worker count variable:

```hcl
worker_count = 0 # initial: one fully functional k3s server
worker_count = 2 # later: one server and two agents
```

Start with one VM. Add two agents only after the first GitOps deployment works and the
host has sufficient free memory. The agents create useful scenarios involving node
failure, scheduling, affinity, DaemonSets, cordon/drain, and resource pressure.

Do not build a three-server HA control plane. That adds etcd and quorum administration
without materially improving the initial interview preparation.

Suggested starting VM resources, subject to preflight inspection:

| Node | vCPU | Memory | Disk |
| --- | ---: | ---: | ---: |
| `practice-cp-1` | 2 | 4 GiB | 30 GiB |
| Each optional worker | 2 | 3 GiB | 25 GiB |

Use an ARM64 Ubuntu LTS cloud image unless preflight uncovers a concrete compatibility
problem. Pin the exact image release and checksum during implementation.

## 5. Ownership by Layer

### Terraform owns

- libvirt network or bridged-network attachment
- base cloud image and VM volumes
- VM CPU, memory, disk, and lifecycle
- cloud-init metadata required to establish SSH access
- deterministic VM names and addresses
- an Ansible inventory derived from Terraform outputs

Terraform must not install k3s using `remote-exec`. Keep configuration management in
Ansible. Keep Terraform state local and gitignored.

### Ansible owns

- base guest OS configuration
- required packages and kernel/sysctl configuration
- k3s server installation and pinned version
- k3s agent installation and joining
- `/etc/rancher/k3s/config.yaml`
- retrieval of a local kubeconfig with its server address corrected
- idempotent host-level verification

Secrets displayed or registered by Ansible must use `no_log: true`. The k3s join token
must not be persisted in the repository or ordinary command output.

### Local bootstrap owns

- installing a pinned Argo CD Helm chart after Kubernetes is reachable
- applying one root Argo CD `Application`

Expose these steps through documented Make targets or small scripts. The wrappers must
print or document the underlying Terraform, Ansible, Helm, and kubectl commands rather
than hiding the learning surface.

### Argo CD owns

- staging and production application releases
- External Secrets Operator and environment-scoped secret references
- Grafana Alloy
- kube-state-metrics
- later Kubernetes add-ons intentionally added to the lab

Argo does not own VM creation, guest OS configuration, k3s installation, or its own
first installation.

### Vault and secret delivery

Vault is the source of truth for application, database, observability, and integration
secrets. Git contains only non-secret references such as Vault addresses, mount names,
paths, policy names, role names, Kubernetes service accounts, and destination Secret
keys.

The preferred Kubernetes integration is External Secrets Operator, managed by Argo CD.
Use separate namespace-scoped `SecretStore` resources and Vault policies for staging
and production. Do not create a broadly privileged cluster-wide store when two scoped
stores are sufficient.

The intended secret hierarchy is similar to the following, adjusted after inspecting
the live Vault mounts and naming conventions:

```text
geno/lab/kubernetes/practice-lab/staging/hello-api
geno/lab/kubernetes/practice-lab/production/hello-api
```

Prefer Vault Kubernetes authentication so workloads receive short-lived, scoped access.
If a bootstrap constraint temporarily requires AppRole, inject its credentials from the
trusted workstation and store them only in a local Kubernetes Secret; never place them
in Terraform variables, Terraform state, Ansible inventory, GitHub secrets, or Git.

Terraform must not read or write secret values through the Vault provider because those
values can be persisted in Terraform state. Ansible may use an already authenticated
local Vault session for bootstrap operations, with `no_log: true`, but secret values
must not be written to repository files or normal logs.

Staging and production must have distinct Vault roles and policies. Promotion copies an
image digest and non-secret desired state only; it never copies staging credentials into
production.

## 6. Planned Repository Layout

```text
practice-lab/
├── .github/
│   └── workflows/
│       ├── validate-infrastructure.yaml
│       ├── validate-application.yaml
│       ├── build-image.yaml
│       ├── publish-chart.yaml
│       ├── update-staging-release.yaml
│       └── promote.yaml
├── apps/
│   └── hello-api/
├── infrastructure/
│   ├── terraform/
│   │   ├── versions.tf
│   │   ├── providers.tf
│   │   ├── variables.tf
│   │   ├── network.tf
│   │   ├── instances.tf
│   │   ├── cloud-init.tf
│   │   ├── outputs.tf
│   │   └── terraform.tfvars.example
│   └── ansible/
│       ├── ansible.cfg
│       ├── requirements.yaml
│       ├── playbooks/
│       ├── roles/
│       │   ├── common/
│       │   ├── k3s_server/
│       │   └── k3s_agent/
│       └── inventory/          # generated/local files ignored
├── bootstrap/
│   └── argocd/
├── platform/                       # initial add-ons and root app only
│   ├── root/
│   ├── secrets/
│   └── observability/
├── charts/
│   └── hello-api/                   # package and publish as a GHCR OCI chart
├── gitops/
│   ├── appsets/
│   └── releases/
│       ├── hello-api-staging.yaml
│       └── hello-api-production.yaml
├── docs/
├── Makefile
└── README.md
```

Generated inventory, Terraform state, downloaded images, kubeconfig, and local secret
files belong in ignored paths. Commit example files containing safe placeholders.

## 7. Environment and Promotion Design

Staging and production initially share the cluster but use separate namespaces and
Argo Applications:

| Environment | Namespace | Argo Application | Sync policy |
| --- | --- | --- | --- |
| Staging | `hello-staging` | `hello-staging` | automated, prune, self-heal |
| Production | `hello-production` | `hello-production` | automated after approved Git change |

This provides deployment and promotion practice, but it is not true infrastructure or
failure-domain isolation. Document that limitation clearly in user-facing architecture
documentation.

### Build once, promote immutable artifacts

Never rebuild an image or a chart during promotion. The detailed target design is in
[`docs/delivery-model.md`](delivery-model.md).

1. An application pull request runs tests, linting, Helm rendering, and a non-pushing
   container build.
2. Merge to `main` builds one `linux/arm64` image and pushes it to GHCR.
3. Record the immutable image digest produced by the registry and its source revision.
4. Publish Helm chart changes as immutable OCI artifacts and record their digests.
5. A staging release-manifest pull request on `main` updates only the selected image
   and/or chart digest.
6. An ApplicationSet generates the staging Application and Argo reconciles it.
7. Run automated smoke checks and inspect Argo/Kubernetes health and telemetry.
8. A manually initiated promotion workflow opens a pull request that copies the exact
   tested image and optionally chart digest into the production release manifest.
9. Review and merge the production promotion pull request.
10. Argo reconciles production from Git.
11. Verify rollout, readiness, logs, metrics, and a user-facing request before
    publishing the final GitHub Release.

The Helm chart should support an image digest explicitly. Do not use `latest` and do
not rely on mutable tags for promotion. The application and chart may publish
human-readable versions or commit-SHA tags for convenience, but release manifests
select OCI digests.

Production approval initially occurs at the pull request boundary. A GitHub
`production` Environment with required reviewers may be added later to practice
environment protection and `workflow_dispatch`, but it must not require cluster
credentials.

### Rollback

Rollback means reverting the production values change to a previously known-good
digest and allowing Argo to reconcile. Do not use an unrecorded `kubectl set image` or
an imperative Helm rollback as the durable fix. Those commands may be used during
investigation, but Git must end in the desired state.

## 8. GitHub Actions Design

### Infrastructure validation

Run on relevant pull-request paths:

- `terraform fmt -check`
- `terraform init -backend=false`
- `terraform validate`
- generate `infrastructure/terraform/README.md` with a pinned `terraform-docs` and
  fail when the committed output is stale
- Ansible syntax checks
- `ansible-lint`
- YAML linting

Do not run `terraform apply` or configure the homelab from a GitHub-hosted runner.

### Application validation

- pin OTP and Elixir versions
- restore dependency/build caches using keys that include OS, OTP, Elixir, `MIX_ENV`,
  and `mix.lock`
- fetch dependencies
- compile with warnings treated appropriately
- run formatter check
- run tests
- run any chosen static-analysis tool
- build the container without pushing

### Container publishing

- run only for trusted pushes to `main`, never untrusted fork pull requests
- use least-privilege workflow permissions (`contents: read`, `packages: write`)
- authenticate to GHCR with the short-lived `GITHUB_TOKEN`
- build `linux/arm64`
- use BuildKit's GitHub Actions cache backend
- publish a commit-SHA tag
- capture the registry digest as workflow output and artifact metadata

Keep Mix dependency caching and Docker layer caching conceptually separate in both the
workflow and documentation.

### Generated component documentation

Keep generated documentation beside the component it describes and commit it:

- `terraform-docs` generates `infrastructure/terraform/README.md` from Terraform
  variables, outputs, providers, and module metadata.
- `helm-docs` generates `charts/hello-api/README.md` from the chart metadata, values,
  and template comments.
- The root README links to these component READMEs; it does not duplicate their
  generated reference material.

Pin the documentation generators in CI. CI must regenerate both documents and fail
when doing so would produce an uncommitted diff. Chart publishing must run Helm lint
and template rendering against every checked-in release manifest before packaging an
OCI artifact.

### Desired-state updates

Prefer promotion pull requests over silently pushing directly to `main`. Avoid workflow
loops by applying path filters and clear commit/PR conventions. Never grant more
repository permission than the update mechanism requires.

## 9. Helm Chart Requirements

Use ordinary, readable templates:

- `Chart.yaml`
- `values.yaml`
- `values.schema.json`
- `_helpers.tpl`
- Deployment
- Service
- optional Ingress
- ConfigMap only for non-secret runtime configuration

The chart must support:

- image repository, tag, and digest
- replica count
- resource requests and limits
- liveness and readiness probes
- environment-specific non-secret values
- references to an existing Kubernetes Secret
- no literal secret values in chart defaults, templates, or environment values
- pod annotations for metric discovery
- rollout behavior suitable for staging and production

CI must run `helm lint`, `helm template`, and rendered-manifest schema validation for
every checked-in release manifest, and must verify that the committed Helm README is
current.

## 10. Elixir Application Scope

Phase two introduces a small Phoenix application with:

- Phoenix and Bandit
- Ecto and Postgrex
- `/` returning application version and environment information
- `/health/live` proving the BEAM and HTTP server are alive
- `/health/ready` checking required runtime dependencies, including PostgreSQL when
  enabled
- `/metrics` exposing useful application and BEAM metrics
- one simple database-backed endpoint
- runtime configuration from environment variables
- release packaging through `mix release`
- a multi-stage Docker build

Use dedicated, least-privilege staging and production practice database users. Do not
reuse an administrative database credential. Store their connection information and
Phoenix secret material in Vault, and deliver them through environment-scoped
`ExternalSecret` resources. The public repository contains only the references.

The dependency set should be realistic enough to demonstrate caching, but dependencies
must not be added solely to make builds slow.

## 11. Existing Observability Integration

Do not deploy a second Prometheus, Loki, or Grafana stack in k3s.

Argo should deploy Grafana Alloy and kube-state-metrics. Alloy should:

- discover Kubernetes workloads
- scrape kubelet/container and kube-state metrics as appropriate
- scrape the Phoenix `/metrics` endpoint using simple Kubernetes annotations initially
- read Kubernetes pod/container logs
- attach stable labels including `cluster=practice-lab`, `environment`, `namespace`,
  `pod`, `container`, and application name
- remote-write metrics to Prometheus on `pi5-1`
- push logs to Loki on `pi5-1`
- buffer or retry transient backend failures without blocking the application

If authentication is added to the receiving endpoints, store those credentials in
Vault and deliver them to Alloy through an `ExternalSecret` rather than Helm values.

The receiving-side `home-docker` change is a separate, reviewed phase:

1. Enable Prometheus's remote-write receiver.
2. Confirm Loki's push endpoint from the practice VM network.
3. Restrict ports `9090` and `3100` with host/network firewall rules so only intended
   lab sources can ingest telemetry.
4. Add a small Grafana dashboard or adapt an existing dashboard using the
   `cluster="practice-lab"` label.
5. Verify that loss of `pi5-1` does not make application readiness fail.

Do not modify `home-docker` until the k3s cluster is working and the user explicitly
approves that phase.

Distributed tracing is out of scope initially because the existing stack has no Tempo
backend. It can be added later without changing the basic delivery architecture.

## 12. Phased Execution Plan

### Phase 0: Preflight and decisions

Perform read-only inspection first:

- confirm `mb1` CPU architecture, memory, disk capacity, and free resources
- confirm `/dev/kvm`, libvirt daemon/socket, `virsh`, storage pools, and networks
- inventory existing VMs and ensure proposed names do not collide
- inspect firewalld and LAN/bridge configuration
- decide whether Terraform runs locally on `mb1` or remotely from the Mac
- select a collision-free VM addressing method
- verify Mac-side Terraform, Ansible, and SSH prerequisites
- record pinned component versions and image checksums
- inspect Vault auth methods, mounts, and existing naming conventions without printing
  secret data

Do not install packages or change host networking until the inspection results are
presented to the user.

Acceptance criteria:

- chosen libvirt connection method works read-only
- proposed VM network allows the Mac to reach the Kubernetes API
- resource allocation will not starve existing Swarm workloads
- no IP, VM name, storage-pool, or network collision exists

### Phase 1: Terraform VM provisioning

- run the committed libvirt bootstrap script when the conventional default network and
  storage pool have not yet been registered on MB1
- create minimal Terraform configuration
- create one control-plane VM
- use cloud-init only for hostname, user, SSH key, and minimal bootstrapping
- generate machine-readable outputs and Ansible inventory
- document plan/apply/destroy operations

Acceptance criteria:

- `terraform fmt -check` and `terraform validate` pass
- repeated `terraform plan` after apply reports no unintended changes
- VM survives reboot and is reachable by SSH
- existing `mb1` workloads are unaffected

### Phase 2: Ansible and single-node k3s

- implement idempotent common and k3s server roles
- pin k3s version
- configure through `/etc/rancher/k3s/config.yaml`
- fetch a local, ignored kubeconfig
- add verification tasks

Acceptance criteria:

- second Ansible run is idempotent
- `kubectl get nodes` reports one Ready node
- CoreDNS and the selected default networking/ingress components are healthy
- a temporary test pod can resolve DNS and reach the internet

### Phase 3: Argo bootstrap and first Helm deployment

- install pinned Argo CD via Helm from the trusted workstation
- apply root Application
- create staging/production namespaces and Applications through GitOps
- deploy External Secrets Operator and scoped Vault `SecretStore` resources before any
  workload requires secret material
- deploy a tiny pinned public container through the initial Helm chart

Acceptance criteria:

- both Argo Applications are Synced and Healthy
- staging and production use separate namespaces and value files
- changing staging values affects only staging
- reverting Git restores desired state
- each environment's Vault identity can read only its own practice-lab path

### Phase 4: CI validation

- add infrastructure and Helm validation workflows
- use path filters and least-privilege permissions
- upload rendered manifests as an optional debugging artifact

Acceptance criteria:

- valid pull request passes
- deliberately invalid Terraform and Helm changes fail in the expected jobs
- workflow job dependencies and conditions are documented

### Phase 5: Phoenix application and image pipeline

- create the Phoenix application
- add tests, releases, Dockerfile, and caches
- publish a GHCR ARM64 image on trusted main-branch changes
- deploy by immutable digest
- create environment-scoped `ExternalSecret` resources for Phoenix and database values

Acceptance criteria:

- tests pass locally and in CI
- repeated unchanged builds demonstrate useful cache hits
- the image runs on ARM64 k3s
- no build tools or source tree are present unnecessarily in the runtime image
- the deployed version can be identified from the application response and image digest
- no secret value is present in Git, Terraform state, rendered Helm output, or GitHub
  Actions logs

### Phase 6: Staging-to-production promotion

- implement staging desired-state update
- add staging smoke test that does not require inbound GitHub access
- implement manually initiated production promotion PR
- document rollback

Acceptance criteria:

- staging receives the image first
- production remains unchanged until its values PR is merged
- production receives the exact staging digest without rebuilding
- reverting the production Git change performs a durable rollback

The smoke test may run locally or as a Kubernetes Job managed from Git. Do not solve it
by exposing the homelab to a GitHub-hosted runner.

### Phase 7: Central observability

- make the separately reviewed receiver changes in `home-docker`
- deploy Alloy and kube-state-metrics using Argo
- add Phoenix metrics
- provision or update a focused Grafana dashboard

Acceptance criteria:

- metrics from the practice cluster appear with a `cluster=practice-lab` label
- logs can be queried by environment, namespace, pod, and container
- staging and production application telemetry can be separated
- stopping the observability backend does not make the application unhealthy

### Phase 8: Optional workers and troubleshooting scenarios

- set `worker_count = 2`
- run Ansible to join agents
- verify workload distribution
- begin controlled interview scenarios only after documenting a known-good baseline

Acceptance criteria:

- all three nodes are Ready
- normal application replicas can run on workers
- node loss and recovery can be practiced without destroying the control plane

## 13. Known-Good Baseline

Before injecting failures, record:

- Git commit and image digest
- Terraform plan showing no drift
- Ansible idempotency result
- External Secrets Operator and environment `SecretStore` readiness
- Kubernetes node and system-pod status
- Argo sync and health status
- Helm rendering result for both environments
- application smoke-test output
- representative Prometheus metric query
- representative Loki log query

This baseline separates genuine exercise failures from incomplete installation.

## 14. Deferred Work

Explicitly defer:

- HA control plane and etcd failure exercises
- Longhorn or other distributed storage
- cert-manager and public certificates
- service mesh
- external DNS automation
- full kube-prometheus-stack
- self-hosted GitHub Actions runners
- direct GitHub deployment into the cluster
- distributed tracing/Tempo
- progressive-delivery controllers such as Argo Rollouts

These can be added later only when they support a specific exercise.

## 15. Execution Instructions for a Codex Agent

This plan is intended to be executable by GPT-5.6 Terra or a similarly capable coding
agent. [Official OpenAI documentation](https://developers.openai.com/api/docs/models/gpt-5.6-terra)
describes Terra as balancing capability and cost; the plan therefore makes decisions
and verification gates explicit rather than relying on the executor to infer
architecture from chat history.

When executing this plan:

1. Read this entire document, the repository README, repository guidance files, and the
   relevant current files before editing.
2. Work one numbered phase at a time. Do not jump ahead to the Phoenix application or
   observability before the cluster baseline works.
3. At the beginning of each phase, inspect current state and state the intended changes.
4. Preserve unrelated user changes and never reset a dirty worktree.
5. Use current official documentation for version-sensitive Terraform, libvirt, k3s,
   Argo CD, Helm, GitHub Actions, Grafana Alloy, Phoenix, and Elixir behavior.
6. Pin versions and image digests. Do not introduce `latest` tags.
7. Keep secrets and generated state out of Git. Update `.gitignore` before generating
   potentially sensitive files. Treat Vault as the authoritative secret source and
   never print secret values while inspecting or configuring it.
8. Do not modify `home-docker` or the live Swarm until its observability phase is reached
   and the user approves the cross-repository change.
9. Before any host networking, firewall, package installation, VM deletion, or other
   material infrastructure mutation, show the discovered target and intended change.
10. Prefer Terraform plans, Ansible check/syntax modes, Helm rendering, and Kubernetes
    dry-run/schema validation before applying.
11. Verify every phase against its acceptance criteria. Report exact failures rather
    than weakening the criteria or claiming success.
12. Keep wrappers small and transparent. The user is practicing the underlying tools.
13. Record material deviations and decisions in this document or a dedicated decision
    log.
14. Do not commit, push, open pull requests, change live infrastructure, or create
    external credentials unless the user has authorized that action.

Recommended execution request:

> Execute Phase N of `docs/implementation-plan.md`. Inspect first, follow its ownership
> boundaries and acceptance criteria, make only in-scope repository changes, and stop
> before any unapproved live-infrastructure or cross-repository mutation.

## 16. Open Decisions to Resolve During Preflight

- Terraform execution location: Mac with remote libvirt transport, or locally on `mb1`
- bridged LAN networking versus a routed libvirt network
- VM address allocation and reservation
- exact Ubuntu ARM64 LTS image and checksum
- exact pinned Terraform provider, k3s, Helm chart, Argo CD, Alloy, OTP, Elixir, and
  Phoenix versions
- whether the public GHCR package requires any pull secret
- dedicated practice PostgreSQL database location, Vault paths, auth mount, and scoped
  staging/production policies
- whether production promotion uses only PR review or also a protected GitHub
  Environment

Resolve these with evidence during the relevant phase; do not guess values that might
conflict with the live homelab.
