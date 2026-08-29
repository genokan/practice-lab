# practice-lab

An intentionally small SRE interview practice environment built around Terraform,
Ansible, k3s, Helm, Argo CD, GitHub Actions, and a simple Elixir application.

The current baseline is a single-node k3s cluster with Argo CD, light observability,
and separate staging/production GitOps applications. See the
[implementation plan](docs/implementation-plan.md) for the architecture, phased
execution plan, promotion workflow, and acceptance criteria.

The current VM provisioning commands and their safety boundaries are documented in
[Phase 1 operations](docs/phase-1-operations.md).
