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
It contains the Argo-only mapping: chart repository, chart revision, target namespace,
release name, and each environment's values-file path.

## Delivery and promotion

1. An application merge publishes an immutable ARM64 image, and optionally a new OCI
   chart artifact.
2. Application CI opens a PR in `practice-lab` updating only
   `k8s/apps/<app>/values/staging.yaml` to select the new image digest.
3. Merging the PR makes Argo auto-sync staging.
4. A release workflow opens a prod PR updating only
   `k8s/apps/<app>/values/prod.yaml` to copy the tested staging image digest.
5. Merging that PR makes Argo auto-sync prod. A draft release can be published
   after local verification.

Cross-repository PR creation uses a narrowly scoped GitHub App installation token.
The default `GITHUB_TOKEN` is not sufficient to write to a different repository.
This automation is intentionally not configured yet; adding the GitHub App
credentials is part of the next delivery-automation phase.

Normally both generated Applications select the same chart revision. If a chart
template change must be trialed in staging first, the single ApplicationSet may select
different immutable revisions for its staging and production generated Applications.
It is still one chart for the application; values files remain values-only.

## Secrets

Vault remains authoritative. Application Helm values contain only references to
Kubernetes Secrets. External Secrets Operator reads scoped Vault paths and writes the
native Kubernetes Secrets consumed by workloads. Vault Kubernetes authentication and
the Vault Agent Injector will be configured as platform capabilities; the injector is
available for file-based runtime secret injection, while External Secrets is the
normal choice when a chart consumes a Kubernetes Secret.
