# Kyverno Pre-built Policies - Common security and best practice policies
# https://kyverno.io/policies/

resource "helm_release" "kyverno_policies" {
  count      = var.enable_kyverno && var.enable_kyverno_policies ? 1 : 0
  name       = "kyverno-policies"
  repository = "https://kyverno.github.io/kyverno/"
  chart      = "kyverno-policies"
  version    = var.kyverno_policies_chart_version
  namespace  = "kyverno"
  create_namespace = false

  values = [
    yamlencode({
      # Pod Security Standards - Baseline profile
      podSecurityStandard = "baseline"
      
      # Include specific policy categories
      include = [
        "pod-security-standard-baseline",
        "best-practices",
        "security"
      ]

      # Exclude policies that might conflict with service mesh requirements
      exclude = [
        "restrict-seccomp-strict",  # May conflict with Istio sidecars
        "require-run-as-non-root-user"  # May conflict with init containers
      ]

      # Policy enforcement mode
      policyViolationAction = "enforce"

      # Namespace exclusions (same as main Kyverno config)
      namespaceSelector = {
        matchExpressions = [
          {
            key      = "kubernetes.io/metadata.name"
            operator = "NotIn"
            values   = var.kyverno_policy_exclusions
          }
        ]
      }

      # Background scanning configuration
      background = true
    })
  ]

  depends_on = [
    helm_release.kyverno
  ]
}