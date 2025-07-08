terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14.0"
    }
    github = {
      source  = "integrations/github"
      version = ">= 5.0.0"
    }
  }
}
