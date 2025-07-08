provider "github" {
  token = var.github_token
}

resource "github_repository" "argocd_apps" {
  name        = var.github_repo_name
  description = "Kubernetes application configurations managed by Argo CD"
  visibility  = "public"
}
