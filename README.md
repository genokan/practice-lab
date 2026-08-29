# practice-lab

An intentionally small SRE interview practice environment built around Terraform,
Ansible, k3s, Helm, Argo CD, GitHub Actions, and a simple Elixir application.

The current baseline is a single-node k3s cluster with Argo CD, light observability,
and separate staging/production GitOps applications. See the
[implementation plan](docs/implementation-plan.md) for the architecture, phased
execution plan, promotion workflow, and acceptance criteria.

The current VM provisioning commands and their safety boundaries are documented in
[Phase 1 operations](docs/phase-1-operations.md).

Pull-request checks and their explicit non-deployment boundary are documented in
[Phase 4 operations](docs/phase-4-operations.md).

The initial Phoenix service lives in [apps/hello-api](apps/hello-api). It is
safe to run without a database until environment-scoped Vault secrets are available.

The next delivery phase is documented in [OCI chart delivery and promotion](docs/delivery-model.md).
