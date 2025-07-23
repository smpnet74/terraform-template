# Naming Conventions Reference

## Feature & Operator Module Manifests

All Kubernetes manifest files generated or applied by feature and operator modules must follow a consistent naming pattern. This ensures clarity, discoverability, and easy automation.

### General Pattern

```text
<resource-type>[-<scope>]-<purpose>[-<identifier>].yaml
```

- `<resource-type>`: lowercase, concatenated name of the Kubernetes kind (no spaces). E.g., `servicemonitor`, `referencegrant`, `serviceaccount`, `kyvernopolicy`, `httproute`, `networkpolicy`, `authorizationpolicy`, `certificate`, etc.
- `<scope>` (optional): namespace or module scope, e.g., `grafana`, `istio`, `argo`, etc.
- `<purpose>`: brief descriptor of the manifest’s role, e.g., `metrics`, `external`, `monitoring`, `security`, etc.
- `<identifier>` (optional): unique suffix if multiple files share the same type, scope, and purpose.

### Resource Types

| Kind                     | Prefix           |
|--------------------------|------------------|
| ServiceMonitor           | `servicemonitor` |
| ReferenceGrant           | `referencegrant` |
| ServiceAccount           | `serviceaccount` |
| KyvernoPolicy            | `kyvernopolicy`  |
| HTTPRoute                | `httproute`      |
| NetworkPolicy            | `networkpolicy`  |
| AuthorizationPolicy      | `authorizationpolicy` |
| Certificate              | `certificate`    |
| Gateway                  | `gateway`        |
| ConfigMap                | `configmap`      |
| Secret                   | `secret`         |

### Examples

```text
servicemonitor-grafana-metrics.yaml
referencegrant-argo-workflows.yaml
serviceaccount-prometheus-operator.yaml
kyvernopolicy-disallow-privilege-escalation.yaml
httproute-gateway-api-external.yaml
networkpolicy-db-isolation.yaml
authorizationpolicy-istio-mtls.yaml
certificate-letsencrypt-cloudflare.yaml
```

### Best Practices

- Use only lowercase letters and hyphens (`-`). Avoid underscores and uppercase.
- Keep filenames concise but descriptive.
- Order segments from general to specific (type → scope → purpose → identifier).
- Append numeric or unique identifiers only when necessary to distinguish files.

---

*Document maintained by Platform Engineering. Last updated: 2025-07-23.*
