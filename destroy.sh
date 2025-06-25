#!/bin/bash

# destroy.sh - Controlled destruction of Terraform resources
# This script destroys resources in a specific order to avoid dependency issues

set -e  # Exit on any error
echo "Starting controlled destruction of resources..."

# Step 1: Destroy Argo CD resources first
echo "Step 1: Destroying Argo CD resources..."
terraform destroy -target=kubectl_manifest.root_app -auto-approve
terraform destroy -target=kubernetes_ingress_v1.argocd -auto-approve
terraform destroy -target=helm_release.argocd -auto-approve
terraform destroy -target=kubernetes_namespace.argocd -auto-approve

# Step 2: Destroy cert-manager resources
echo "Step 2: Destroying cert-manager resources..."
terraform destroy -target=kubectl_manifest.letsencrypt_prod_issuer -auto-approve
terraform destroy -target=kubectl_manifest.letsencrypt_issuer -auto-approve
terraform destroy -target=kubernetes_secret.cloudflare_api_token_secret -auto-approve
terraform destroy -target=helm_release.cert_manager -auto-approve
terraform destroy -target=kubernetes_namespace.cert_manager -auto-approve

# Step 3: Destroy Traefik resources
echo "Step 3: Destroying Traefik resources..."
terraform destroy -target=helm_release.traefik_ingress -auto-approve

# Step 4: Destroy DNS records
echo "Step 4: Destroying DNS records..."
terraform destroy -target=cloudflare_dns_record.root -auto-approve
terraform destroy -target=cloudflare_dns_record.wildcard -auto-approve

# Step 5: Destroy GitHub resources
echo "Step 5: Destroying GitHub resources..."
terraform destroy -target=github_repository_file.nginx_app -auto-approve
terraform destroy -target=github_repository_file.nginx_manifest -auto-approve
terraform destroy -target=github_repository_file.longhorn_app -auto-approve
terraform destroy -target=github_repository.argocd_apps -auto-approve

# Step 6: Destroy the Kubernetes cluster
echo "Step 6: Destroying Kubernetes cluster..."
terraform destroy -target=civo_kubernetes_cluster.cluster -auto-approve
terraform destroy -target=local_file.cluster-config -auto-approve

# Step 7: Wait for 60 seconds to ensure the cluster is fully destroyed
echo "Step 7: Waiting 60 seconds for cluster resources to be fully released..."
sleep 60

# Step 8: Destroy the firewalls
echo "Step 8: Destroying firewalls..."
terraform destroy -target=civo_firewall.firewall-ingress -auto-approve
terraform destroy -target=civo_firewall.firewall -auto-approve

# Step 9: Destroy any remaining resources
echo "Step 9: Destroying any remaining resources..."
terraform destroy -auto-approve

echo "Destruction complete!"
