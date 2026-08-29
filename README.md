# practice-lab

`practice-lab` is the infrastructure and GitOps management repository for a small,
rebuildable k3s lab on MB1. It owns the VM, k3s bootstrap, Argo CD, shared
observability, Vault integration, and the desired deployment configuration for
workloads. It deliberately does **not** own application source code, Dockerfiles, or
Helm charts.

## Repository boundary

Application repositories own their code, one Helm chart per application, tests, and
publishing immutable image and chart artifacts. This repository owns one Argo CD
ApplicationSet manifest per deployed application and two values files for it:

```text
infra/                         # VM provisioning and initial bootstrap
  ansible/
  bootstrap/
  scripts/
  terraform/
k8s/                           # Argo-managed cluster desired state
  apps/
    <application>/
      appset.yaml
      values/
        staging.yaml
        prod.yaml
  platform/
docs/
```

The reference application is
[practice-hello-api](https://github.com/genokan/practice-hello-api). It owns the
Phoenix service, Docker image, and OCI Helm chart; this repository selects the
immutable chart and image digests deployed to staging and prod.

The ApplicationSet renders the application's one OCI chart for both environments;
the two values files provide the environment differences. Application CI opens a
reviewed pull request here to update a staging image digest. Promotion opens a
reviewed pull request changing the production values. Argo CD only pulls and
reconciles committed state.

See [the implementation plan](docs/implementation-plan.md),
[the GitOps delivery model](docs/delivery-model.md), and
[the rationale for this split](docs/architecture-rationale.md). The generated
[Terraform module reference](infra/terraform/README.md) lives beside the
module it describes.

## Current platform components

- Terraform and Ansible provision the single-node k3s VM on MB1.
- Argo CD owns shared in-cluster add-ons after its initial local bootstrap.
- Grafana Alloy sends logs and lightweight Kubernetes metrics to the existing
  homelab Loki and Prometheus services.
- External Secrets Operator is installed. Vault Kubernetes authentication, scoped
  stores, and the Vault Agent Injector are the next secrets-integration work.

The normal Terraform, Ansible, Helm, and `kubectl` commands remain usable directly.
The small scripts in `infra/scripts/` only handle libvirt prerequisites and reproducible
cloud-image/inventory setup; they are not a Kubernetes command wrapper.
