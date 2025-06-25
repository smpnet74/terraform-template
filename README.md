# Kubernetes GitOps Deployment with Terraform

This repository contains a complete solution for deploying and managing a Kubernetes cluster on Civo using Terraform, with GitOps principles implemented through Argo CD. The architecture includes Traefik as an ingress controller, cert-manager for automated TLS certificates via Cloudflare DNS, and a GitHub repository for application manifests.

## Architecture Overview

This solution implements a complete GitOps workflow with the following components:

1. **Civo Kubernetes Cluster**: Managed Kubernetes cluster on Civo Cloud
2. **Traefik Ingress Controller**: Handles incoming traffic to the cluster
3. **Argo CD**: GitOps continuous delivery tool that synchronizes the desired state from Git
4. **cert-manager**: Automates TLS certificate issuance and renewal using Let's Encrypt
5. **GitHub Repository**: Stores Kubernetes manifests for applications (App of Apps pattern)
6. **Cloudflare DNS**: Manages DNS records and facilitates DNS-01 challenge for certificate issuance

## File Structure and Purpose

### Core Infrastructure

- **`provider.tf`**: Configures the required Terraform providers (Civo, Kubernetes, Helm, GitHub, kubectl, Cloudflare, time, etc.)
- **`io.tf`**: Defines all input and output variables used throughout the Terraform configuration
- **`cluster.tf`**: Creates the Civo Kubernetes cluster and saves the kubeconfig locally

### Firewall Configuration

- **`civo_firewall-cluster.tf`**: Defines the firewall for the Kubernetes API server (port 6443)
- **`civo_firewall-ingress.tf`**: Defines the firewall for HTTP/HTTPS ingress traffic (ports 80/443)
- **`firewall_destroy_delay.tf`**: Implements a 60-second delay before firewall destruction to prevent dependency conflicts during `terraform destroy`

### Ingress and DNS

- **`helm_traefik.tf`**: Installs Traefik ingress controller via Helm
- **`cloudflare_dns.tf`**: Creates DNS records in Cloudflare pointing to the Traefik load balancer

### TLS Certificate Management

- **`helm_cert_manager.tf`**: Installs cert-manager via Helm for automated TLS certificate management
- **`kubernetes_cert_manager.tf`**: Configures cert-manager ClusterIssuers for Let's Encrypt staging and production environments, and creates a Kubernetes secret for Cloudflare API token

### Argo CD and GitOps

- **`helm_argocd.tf`**: Installs Argo CD via Helm with proper configuration for TLS termination
- **`kubernetes_ingress-argocd.tf`**: Creates an ingress resource for Argo CD with TLS configuration
- **`argocd_applications.tf`**: Defines the root Argo CD application using the kubectl provider to avoid CRD race conditions
- **`github.tf`**: Creates and populates a GitHub repository with Kubernetes manifests for applications

### Additional Resources

- **`kubernetes_secret_object_store.tf`**: Template for creating Kubernetes secrets (if needed)
- **`civo_object_store-template.tf`**: Template for Civo object store configuration (if needed)
- **`outputs.tf`**: Defines useful outputs like Argo CD URL and admin password retrieval instructions

## Deployment Process

### Prerequisites

1. A Civo account with API access
2. A GitHub account with a Personal Access Token
3. A Cloudflare account with a domain and API token with DNS edit permissions
4. Terraform installed locally

### Configuration

1. Copy `terraform.tfvars.example` to `terraform.tfvars`:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Update `terraform.tfvars` with your specific values:
   ```hcl
   civo_token = "your-civo-api-token"
   github_token = "your-github-personal-access-token"
   domain_name = "your-domain.com"
   cloudflare_api_token = "your-cloudflare-api-token"
   cloudflare_zone_id = "your-cloudflare-zone-id"
   cloudflare_email = "your-cloudflare-email"
   ```

### Deployment Steps

1. Initialize Terraform:
   ```bash
   terraform init
   ```

2. Plan the deployment:
   ```bash
   terraform plan
   ```

3. Apply the configuration:
   ```bash
   terraform apply
   ```

4. After successful deployment, Terraform will output the Argo CD URL and instructions to retrieve the admin password:
   ```bash
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
   ```

### Destruction Process

To destroy the infrastructure:

```bash
terraform destroy
```

Note: The destruction process includes a 60-second delay before removing firewalls to ensure proper cleanup of dependent resources.

## GitOps Workflow with Argo CD

### App of Apps Pattern

This solution implements the Argo CD "App of Apps" pattern:

1. A root Argo CD Application is deployed via Terraform
2. This root application points to the `apps` directory in the GitHub repository
3. The `apps` directory contains Application manifests for each application
4. Each Application manifest points to its respective directory in the repository

### Adding New Applications

To add a new application:

1. Create a new directory in the GitHub repository for your application manifests
2. Create a new Application manifest in the `apps` directory
3. Commit and push the changes
4. Argo CD will automatically detect and deploy the new application

### TLS Certificate Management

The solution includes automatic TLS certificate issuance and renewal:

1. cert-manager is installed and configured with Let's Encrypt ClusterIssuers
2. DNS-01 challenge is used with Cloudflare for domain validation
3. Ingress resources are annotated to request certificates automatically
4. Certificates are stored as Kubernetes secrets and used by Traefik

## Troubleshooting

### Argo CD Redirect Loops

If you encounter redirect loops with Argo CD:

1. Verify that the Argo CD server is configured with the `--insecure` flag
2. Check that the `configs.cm.url` is set to the correct public URL
3. Ensure the ingress is properly configured with TLS

### Certificate Issuance Issues

If certificates are not being issued:

1. Check the cert-manager logs: `kubectl logs -n cert-manager -l app=cert-manager`
2. Verify the Cloudflare API token has the correct permissions
3. Check Certificate resources: `kubectl get certificates -A`

## Important Notes

1. The deployment is configured to use Let's Encrypt production environment by default
2. Both staging and production ClusterIssuers are created, but the ingress is configured to use the production issuer
3. Argo CD admin password is randomly generated; retrieve it using the provided command
4. Custom Resource Definitions (CRDs) from Helm charts may remain after `terraform destroy`

## Security Considerations

1. API tokens and secrets are stored securely in Terraform variables and Kubernetes secrets
2. Firewall rules restrict access to the Kubernetes API and web services
3. TLS certificates are automatically managed and renewed
4. Argo CD is configured with proper TLS termination at the ingress level
