terraform {
  required_providers {
    #  User to provision resources (firewal / cluster) in civo.com
    civo = {
      source  = "civo/civo"
      version = "1.0.35"
    }

    # Used to output the kubeconfig to the local dir for local cluster access
    local = {
      source  = "hashicorp/local"
      version = "2.5.1"
    }

    # Used to provision helm charts into the k8s cluster
    helm = {
      source  = "hashicorp/helm"
      version = "2.13.1"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.31.0"
    }

    # Used to manage DNS records in Cloudflare
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.5.0"
    }

    # Used to manage the github repository for GitOps
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }

    # Used to apply raw Kubernetes YAML, avoiding provider caching issues
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }

    # Used to manage time
    time = {
      source  = "hashicorp/time"
      version = "~> 0.10.0"
    }

  }
}


# Configure the Civo Provider
provider "civo" {
  token  = var.civo_token
  region = var.region
}

provider "helm" {
  kubernetes {
    host                   = civo_kubernetes_cluster.cluster.api_endpoint
    client_certificate     = base64decode(yamldecode(civo_kubernetes_cluster.cluster.kubeconfig).users[0].user.client-certificate-data)
    client_key             = base64decode(yamldecode(civo_kubernetes_cluster.cluster.kubeconfig).users[0].user.client-key-data)
    cluster_ca_certificate = base64decode(yamldecode(civo_kubernetes_cluster.cluster.kubeconfig).clusters[0].cluster.certificate-authority-data)
  }
}

provider "kubernetes" {
  host                   = civo_kubernetes_cluster.cluster.api_endpoint
  client_certificate     = base64decode(yamldecode(civo_kubernetes_cluster.cluster.kubeconfig).users[0].user.client-certificate-data)
  client_key             = base64decode(yamldecode(civo_kubernetes_cluster.cluster.kubeconfig).users[0].user.client-key-data)
  cluster_ca_certificate = base64decode(yamldecode(civo_kubernetes_cluster.cluster.kubeconfig).clusters[0].cluster.certificate-authority-data)
}

# kubectl provider is already defined in kubectl_dependencies.tf
