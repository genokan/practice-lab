# Phase 4 operations: pull-request validation

`.github/workflows/validate-infrastructure.yaml` is a read-only GitHub Actions
workflow. It runs only for pull requests that change infrastructure or GitOps files,
and can also be started manually.

It has three independent jobs:

- **Terraform** checks formatting, initializes with no backend, and validates the
  configuration. It does not use the libvirt URI or run a plan/apply.
- **Ansible** runs YAML lint, `ansible-lint`, and a syntax check against a local-only
  inventory. It does not connect to MB1.
- **Helm and Kubernetes manifests** lints the chart, renders both environment values
  files, and renders the Argo root Kustomization. It does not contact the cluster.

The workflow has only `contents: read` permission. It contains no kubeconfig,
homelab network access, Vault credentials, or deployment step. A later image-build
workflow will have separate, narrowly scoped GHCR publishing permission.
