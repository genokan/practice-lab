# Phase 6 operations: CI/CD promotion and failure practice

## CI/CD flow

`practice-hello-api` owns two CD workflows and its existing CI workflow:

| Trigger | Workflow | Result |
| --- | --- | --- |
| Application/Docker pull request or main push | **CI — Validate application** | Tests the Phoenix app. It does not publish or deploy. |
| Chart pull request or main push | **CI — Validate Helm chart** | Lints, templates, and regenerates Helm chart docs. It does not publish or deploy. |
| Application/Docker merge to `main` | **CD — Publish image and propose staging** | Publishes an immutable image digest and opens or updates an image-only staging PR. |
| Chart merge to `main` | **CD — Publish chart and propose staging** | Requires a chart-version bump, publishes an immutable OCI chart digest, and opens or updates a chart-only staging PR. |
| GitHub release published | **CD — Promote production** | Opens or updates a prod PR copying the exact staged image and chart digests. |

The only cross-repository credential is `MANIFESTS_TOKEN`, a fine-grained PAT stored
as an Actions secret in `practice-hello-api`. It has access only to this repository
and only Contents/Pull requests write permissions. It has no cluster or Vault access.

Argo CD auto-syncs only after a person merges the generated values PR. It never
builds artifacts and GitHub Actions never reaches the homelab.

Changing application code does not republish the chart, and changing the chart does
not rebuild the image. A combined application/chart merge legitimately produces one
image PR and one chart PR so each immutable selection is independently reviewable.

## Intentional failure exercises

Use a short-lived branch and PR in this repository for each exercise; Argo will then
show the failure as ordinary desired-state drift. Revert or close the PR to recover.

| Exercise | Change | Observe |
| --- | --- | --- |
| Image failure | Set a nonexistent image digest in staging values. | `ImagePullBackOff`, Argo health, Alloy logs. |
| Readiness failure | Change the app chart probe path in an application-chart branch, publish it, then select that staging chart digest. | Unready Pods and unavailable Deployment. |
| Secret failure | Add an `ExternalSecret` referencing a nonexistent Vault path. | `ExternalSecret` status/events while the app stays unchanged. |
| Resource pressure | Temporarily set staging requests above node capacity. | Pending Pod, scheduler event, node/pod metrics. |

Do not inject a real secret value merely to practice failure recovery. The secret-path
exercise is sufficient and leaves Vault values untouched.
