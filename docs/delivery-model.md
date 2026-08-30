# GitOps delivery model

## Ownership

`practice-lab` is the devops-manifests and platform repository. It owns cluster
infrastructure, Argo CD, platform add-ons, ApplicationSet manifests, and the
staging/production Helm values selected by Argo.

Each application repository owns application code, its single Helm chart, CI tests,
and publishing immutable OCI image and chart artifacts. An application is never
copied into this repository.

```text
application repository                  practice-lab
----------------------                  ------------
source, Dockerfile, chart               k8s/apps/<app>/appset.yaml
image/chart CI                           k8s/apps/<app>/values/staging.yaml
immutable OCI artifacts                 k8s/apps/<app>/values/prod.yaml
```

## One ApplicationSet per application

There is one Argo CD instance and one ApplicationSet manifest for each deployed
application. That ApplicationSet declares one chart source and generates two Argo
Applications:

```text
ApplicationSet: <app>
├── Application: <app>-staging     chart + apps/<app>/values/staging.yaml
└── Application: <app>-prod        chart + apps/<app>/values/prod.yaml
```

The chart is the same application chart in both environments. The values files hold
environment-specific runtime configuration such as image digest, ingress hostname,
resources, replicas, and references to Kubernetes Secrets. They never contain secret
values.

The ApplicationSet is Argo configuration, not a Helm chart and not a values file.
It contains the Argo-only mapping: chart repository, immutable chart revision, target
namespace, release name, and each environment's values-file path. Each generated
environment owns its own `chartRevision` here because Argo needs it before it can
render Helm values; the values files remain Helm values only.

## Delivery and promotion

1. A merge to an application's `main` runs only the relevant CD workflow:
   **CD — Publish image and propose staging** for application/Docker inputs, or
   **CD — Publish chart and propose staging** for `chart/**` inputs. A chart change
   must include a chart-version bump before it can publish.
2. The image workflow opens, records, and automatically squash-merges a staging PR
   that changes only the image digest in `values/staging.yaml`. The chart workflow
   does the same for the staging `chartRevision` in the ApplicationSet.
3. Merging either staging PR makes Argo auto-sync the corresponding selection.
4. Publishing a GitHub release runs **CD — Promote production**. It opens or updates
   a **draft** prod PR that copies the tested staging image and chart digests to prod.
5. Merging that PR makes Argo auto-sync prod. The release body is the application
   release note; this repository records only the exact deployment selection.

The application workflow uses the `MANIFESTS_TOKEN` fine-grained PAT, scoped only to
this repository's Contents and Pull requests permissions. `GITHUB_TOKEN` cannot
write to a different repository. A GitHub App can replace this token later without
changing the delivery model.

Staging and prod normally select the same chart revision. Keeping the two immutable
revisions independently in the ApplicationSet means a chart-template change can be
trialed in staging without advancing prod. It is still one chart per application;
values files remain values-only.

## Secrets

Vault remains authoritative. Application Helm values contain only references to
Kubernetes Secrets. External Secrets Operator reads scoped Vault paths and writes the
native Kubernetes Secrets consumed by workloads. Vault Kubernetes authentication and
the Vault Agent Injector will be configured as platform capabilities; the injector is
available for file-based runtime secret injection, while External Secrets is the
normal choice when a chart consumes a Kubernetes Secret.
