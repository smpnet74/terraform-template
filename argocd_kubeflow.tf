module "kubeflow" {
  source = "./modules/kubeflow"

  enable_kubeflow = var.enable_kubeflow
  github_repo_name = github_repository.argocd_apps.name
  github_repo_url = github_repository.argocd_apps.html_url
  github_repository = github_repository.argocd_apps
  domain_name = var.domain_name
  argocd_helm_release = helm_release.argocd
  service_mesh_controller = kubectl_manifest.service_mesh_controller
  wait_for_service_mesh_controller = time_sleep.wait_for_service_mesh_controller
  
  providers = {
    kubectl = kubectl
    github = github
  }
}
