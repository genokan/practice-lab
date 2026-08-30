# Phase 4 operations: platform pull-request validation

The platform validation workflow is read-only. It runs on pull requests that change
Terraform, Ansible, Argo bootstrap, or platform manifests; it can also be started
manually.

- **Terraform** checks formatting, initializes with no backend, and validates the
  configuration. It never connects to MB1.
- **Ansible** runs YAML lint, Ansible lint, and a syntax check. It never connects to
  the guest.
- **Kubernetes manifests** render the Argo root Kustomization. They never contact the
  cluster.

Application source, chart lint/template checks, `helm-docs`, image builds, and OCI
chart publishing belong in each application repository. Their application-side
workflows call this repository's reusable deployment workflow, which writes the
reviewable manifest pull request.
