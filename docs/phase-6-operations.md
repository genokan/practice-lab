# Phase 6 operations: CI/CD promotion and failure practice

## CI/CD flow

`practice-hello-api` owns two workflows:

| Trigger | Workflow | Result |
| --- | --- | --- |
| Pull request | **Build and Publish** | Tests the app, builds an affected image without pushing, and validates/packages an affected chart without publishing. |
| Merge to `main` | **Build and Publish** | Repeats the builds, publishes only changed image/chart artifacts, and auto-merges one staging deployment PR. |
| GitHub release | **Deploy** | Opens or updates a **draft** prod PR containing the exact staged digests. |
| Manual dispatch | **Deploy** | Accepts `environment`, `image_digest`, and `chart_digest`; blank digests preserve the current selection. Staging auto-merges; prod remains draft. |

The only cross-repository credential is `MANIFESTS_TOKEN`, a fine-grained PAT stored
as an Actions secret in `practice-hello-api`. It has access only to this repository
and only Contents/Pull requests write permissions. It has no cluster or Vault access.

Argo CD auto-syncs after the staging workflow merges its generated PR or after a
person merges a draft production PR. It never builds artifacts and GitHub Actions
never reaches the homelab.

Changing application code does not republish the chart, and changing the chart does
not rebuild the image. A combined application/chart merge publishes both artifacts
and produces one staging deployment PR containing both new digests.

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
