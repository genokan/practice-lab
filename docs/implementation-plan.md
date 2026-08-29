# Practice Lab implementation plan

## Purpose

Build a compact, reproducible SRE practice environment on MB1. It should exercise
Terraform, Ansible, k3s, ordinary `kubectl`, Helm, Argo CD, Vault, observability, and
GitHub-based promotion without turning the homelab into a second production platform.

## Scope and ownership

`practice-lab` is the infrastructure and devops-manifests repository. It owns:

- the MB1 libvirt VM and its k3s bootstrap;
- initial Argo CD installation and shared Argo-managed add-ons;
- ingress, light observability, Vault/External Secrets integration, and platform
  policy;
- one Argo ApplicationSet manifest and two environment values files per application.

Application repositories own source code, Docker builds, one Helm chart per
application, chart documentation, tests, and immutable GHCR artifacts. They never
receive a kubeconfig or direct cluster access.

## Current topology

```text
Mac ── SSH/libvirt ──> MB1 ── libvirt NAT ──> practice-cp-1 (k3s)
                                      │
Pi5 Caddy ── LAN relay ──> Traefik ──┴──> Services and Pods
                                      │
Alloy ──> Pi5 Loki / Prometheus ──────┘
Vault ──> External Secrets / Injector ─> workload credentials
```

The lab starts with one ARM64 Ubuntu VM: 2 vCPU, 4 GiB RAM, and a 30 GiB disk. It
uses libvirt's existing `default` NAT network; no project-specific subnet is needed.
The normal Mac kubeconfig has the `practice-lab` context and reaches the API through
MB1.

## GitOps layout

```text
practice-lab/
├── infra/
│   ├── ansible/
│   ├── bootstrap/
│   ├── scripts/
│   └── terraform/
├── k8s/
│   ├── apps/
│   │   └── <application>/
│   │       ├── appset.yaml
│   │       └── values/
│   │           ├── staging.yaml
│   │           └── prod.yaml
│   └── platform/
└── docs/
```

One ApplicationSet per application generates staging and prod Argo Applications. It
renders the application's one OCI chart with the two values files.
The values files contain environment configuration and immutable image selections;
they contain no secret values. See [the delivery model](delivery-model.md) for the
complete ownership and promotion flow.

## Phases

1. **VM and k3s** — complete: Terraform/Ansible build the single-node cluster;
   normal `kubectl` access works from the Mac.
2. **Platform services** — complete baseline: Argo CD, Traefik routing, Alloy,
   kube-state-metrics, and External Secrets Operator are installed.
3. **Vault integration** — next: configure Vault Kubernetes auth, distinct staging
   and production policies/roles, namespace-scoped SecretStores, and the Vault Agent
   Injector. Secret values stay in Vault and are delivered as Kubernetes Secrets or
   injected files as appropriate.
4. **Application onboarding** — create the separate hello-api repository, publish its
   OCI image/chart, then add its ApplicationSet and two values files here.
5. **Promotion and failure practice** — app CI opens a staging values PR; promotion
   opens a production values PR. Add intentional rollout, ingress, secret, and
   resource-pressure failures only after the happy path is repeatable.

## Constraints

- No secrets, kubeconfig, Terraform state, generated credentials, or Vault values in
  Git.
- GitHub Actions do not receive inbound homelab access or cluster credentials.
- Argo CD reconciles desired state but does not build artifacts.
- Do not disrupt MB1 Docker Swarm workloads.
- Prefer standard Terraform, Ansible, Helm, and `kubectl` commands over custom
  wrappers. Repository scripts cover only repeatable host/bootstrap chores.
