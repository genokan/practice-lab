# Application values

Each deployed application receives an application-centred directory containing exactly
the values that differ by environment:

```text
values/<application>/staging.yaml
values/<application>/production.yaml
```

Values select immutable image digests and normal runtime configuration. They contain
only references to Kubernetes Secrets, never secret values.
