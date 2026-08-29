# OCI chart delivery and promotion model

## Status and intent

The initial GitOps baseline is working: Argo CD owns separate staging and production
Applications, and staging runs the Phoenix image selected by digest. The initial
layout deliberately kept the Helm chart in Git and rendered it from `main` to get a
small, observable lab online quickly.

The next delivery phase replaces that temporary model. It keeps one working branch
(`main`) while making every deployable chart and image artifact immutable and
reviewable.

## Ownership boundaries

| System | Owns |
| --- | --- |
| Application CI | Tests the Phoenix source and publishes immutable ARM64 images to GHCR. |
| Chart CI | Lints, renders, documents, packages, and publishes an OCI artifact to GHCR. |
| GitOps release manifests | Select the exact image and chart digests for each release. |
| GitHub pull requests | Review and merge desired-state updates on `main`. |
| Argo CD | Reconciles the selected artifacts after the GitOps change is merged. |

GitHub Actions does not receive cluster credentials. Argo CD does not build artifacts
or write desired state. No workflow writes directly to a workload namespace.

## Target layout

```text
apps/
  hello-api/                         # Phoenix source and container build
charts/
  hello-api/                         # Helm source; packaged to GHCR as OCI
gitops/
  appsets/
    hello-api.yaml                   # generates one Application per release file
  releases/
    hello-api-staging.yaml
    hello-api-production.yaml
bootstrap/
  argocd/                            # initial Helm installation only
platform/
  root/                              # seeded root Application source
```

There are no environment branches and no per-environment directory tree. Release
files are ordinary, reviewed manifests on `main` with explicit names.

## Immutable release selection

Each release file records two OCI digests:

```yaml
name: hello-api-staging
namespace: hello-staging

chart:
  repository: oci://ghcr.io/genokan/charts/hello-api
  digest: sha256:<chart-manifest-digest>
  sourceRevision: <git-commit-that-built-the-chart>

image:
  repository: ghcr.io/genokan/practice-lab/hello-api
  digest: sha256:<image-manifest-digest>
  sourceRevision: <git-commit-that-built-the-image>
```

The chart's semantic version is required by Helm when it is packaged and published,
but it is not the deployment selector. Argo uses the chart digest as the OCI
`targetRevision`. The source revision is provenance only; the OCI digest identifies
the exact bytes that are deployed.

The ApplicationSet reads the release files from `main`, generates an Application for
each one, pulls the chart by digest, and supplies the same release file as Helm
values. The chart schema accepts the release metadata but uses only its normal Helm
values.

## Staging delivery

1. An application merge to `main` runs tests and publishes one ARM64 image.
2. The workflow records the registry digest and opens a pull request that changes
   only `hello-api-staging.yaml`'s image digest and provenance revision.
3. Merging that pull request causes Argo to auto-sync staging.
4. A local or in-cluster smoke check verifies Argo health, readiness, and the staging
   endpoint. GitHub-hosted runners never need inbound homelab access.

Chart CI follows the same pattern only when chart source changes: it lint-renders the
chart against every checked-in release manifest, verifies its generated chart README,
packages and pushes a new OCI chart, then opens a staging release-manifest pull
request that updates the chart digest. Application image changes and chart changes are
independent.

## Generated component documentation

Generated documentation is committed beside the component it describes, not hidden in
workflow output. `helm-docs` generates `charts/hello-api/README.md` from `Chart.yaml`,
`values.yaml`, and template comments. `terraform-docs` generates
`infrastructure/terraform/README.md` from the module's variables, outputs, and
providers. The repository README links to both component READMEs.

CI runs each generator with pinned tooling and fails if regenerating documentation
would change the working tree. This makes a chart value, template interface, or
Terraform input/output change incomplete until its local documentation is updated.

## Production promotion and releases

Manually dispatching the release workflow with a semantic release version selects a
known-good staging release. The workflow opens a production pull request on `main`
and creates a draft GitHub Release with generated notes. It copies the exact tested
image digest and, only when requested, the chart digest. It never rebuilds either
artifact.

After the production pull request merges, Argo auto-syncs production and a local smoke
check confirms rollout health. An operator publishes the draft release only after that
verification, recording the image digest, chart digest, and source revisions. A failed
rollout leaves the release as a draft and is rolled back by a reviewed production
release-manifest revert.

## Chart and application evolution

Staging can move to a new chart digest while production remains on its previous chart
digest. The same holds for application images. This allows image-only, chart-only, or
combined promotions without environment branches or accidental production template
changes.

ApplicationSets are used for the repeated release-file-to-Application mapping. New
services add a chart and their explicitly named staging/production release files; they
do not require a new repository or a universal chart.
