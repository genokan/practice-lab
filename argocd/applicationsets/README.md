# ApplicationSets

Add one ApplicationSet manifest per application deployed to the lab. Its two generated
Applications use the application's one OCI Helm chart and these repository-owned
values files:

```text
values/<application>/staging.yaml
values/<application>/production.yaml
```

Do not place application source, chart source, credentials, or secret values here.
The first real ApplicationSet is added with the separate hello-api repository.
