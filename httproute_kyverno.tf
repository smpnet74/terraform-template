# NOTE: Kyverno itself does not provide a web UI service
# Web-based policy management requires the separate Policy Reporter UI component
# 
# To add Policy Reporter UI in the future:
# 1. Add Policy Reporter Helm chart deployment
# 2. Create HTTPRoute to policy-reporter-ui service on port 8080
# 3. Add ReferenceGrant for cross-namespace access
#
# For now, use kubectl commands to manage policies:
# - kubectl get clusterpolicies
# - kubectl get clusterpolicyreports
# - kubectl describe clusterpolicy <policy-name>

# Placeholder for future Policy Reporter UI integration
# Uncomment and configure when Policy Reporter is added

# resource "helm_release" "policy_reporter" {
#   count      = var.enable_kyverno && var.enable_policy_reporter_ui ? 1 : 0
#   name       = "policy-reporter"
#   repository = "https://kyverno.github.io/policy-reporter"
#   chart      = "policy-reporter"
#   namespace  = "policy-reporter"
#   create_namespace = true
#   
#   values = [
#     yamlencode({
#       ui = {
#         enabled = true
#       }
#       kyvernoPlugin = {
#         enabled = true
#       }
#     })
#   ]
#   
#   depends_on = [
#     helm_release.kyverno
#   ]
# }