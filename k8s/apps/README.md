# ApplicationSets

Add one ApplicationSet manifest per application deployed to the lab. Its two generated
Applications use the application's one OCI Helm chart and these repository-owned
values files:

```text
hello-api/values/staging.yaml
hello-api/values/prod.yaml
```

Do not place application source, chart source, credentials, or secret values here.
`hello-api/appset.yaml` is the first real example: it declares one OCI chart and generates
the staging and production Argo Applications using the two values files.
