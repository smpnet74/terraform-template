# Kubernetes GitOps Deployment with Terraform *

This repository provides a Terraform-based solution to deploy and manage a Civo Kubernetes cluster with GitOps via Argo CD. It leverages Cilium CNI with Hubble for networking and observability, cert-manager for automated TLS (Let's Encrypt via Cloudflare DNS-01), Gateway API & Kgateway for ingress, and a GitHub repository hosting application manifests using the App-of-Apps pattern.

## Architecture Overview

This solution implements a complete GitOps workflow with the following components:

1. **Civo Kubernetes Cluster**: Managed cluster on Civo Cloud
2. **Cilium CNI & Hubble**: Provides pod networking, network policies, and observability
3. **Gateway API & Kgateway**: Implements modern HTTP/HTTPS ingress
4. **cert-manager**: Automates TLS certificate issuance/renewal (Let's Encrypt via Cloudflare DNS-01)
5. **Argo CD**: GitOps continuous delivery tool syncing application manifests
6. **GitHub Repository**: Hosts application manifests using the App-of-Apps pattern
7. **Cloudflare DNS**: Manages DNS A records and ACME challenge validation

## File Structure and Purpose

### Core Infrastructure

- **`provider.tf`**: Configures Terraform providers for Civo, Kubernetes, Helm, GitHub, kubectl, Cloudflare, and Time.
- **`io.tf`**: Defines all input/output variables used throughout the Terraform configuration.
- **`cluster.tf`**: Creates the Civo Kubernetes cluster and writes the kubeconfig.
- **`cluster_ready_delay.tf`**: Adds a delay to ensure the API server is ready before provisioning other resources.
- **`kubectl_dependencies.tf`**: Configures the kubectl provider to wait for cluster readiness.

### Networking (Cilium)

- **`helm_cilium.tf`**: Installs/upgrades Cilium CNI via Helm with Hubble observability. See [Helm Cilium Installation & Config](docs/helm_cilium.md).
- **`cilium_values.yaml`**: Custom configuration values for Cilium and Hubble.

### Firewall Rules

- **`civo_firewall-cluster.tf`**: Firewall for the Kubernetes API server (port 6443).
- **`civo_firewall-ingress.tf`**: Firewall for HTTP/HTTPS ingress traffic (ports 80/443).

### Ingress & DNS

- **`kgateway_api.tf`**: Installs Gateway API CRDs, Kgateway CRDs, and Kgateway release via Helm; defines the default Gateway and its TLS Certificate. See [kgateway API Reference](docs/kgateway_api.md).
- **`cloudflare_dns.tf`**: Creates A records (root and wildcard) in Cloudflare pointing to the Gateway load balancer.
- **`kubernetes_ingress-argocd.tf`**: Configures HTTPRoute for Argo CD via Gateway API.
- For troubleshooting Kgateway, see [kgateway Troubleshooting](docs/kgateway_troubleshooting.md).

### TLS Certificate Management

- **`helm_cert_manager.tf`**: Installs cert-manager via Helm for automated certificate management. See [Certificate Troubleshooting](docs/certificate_troubleshooting.md).
- **`kubernetes_cert_manager.tf`**: Defines staging and production ClusterIssuers and the Cloudflare API token secret.

### GitOps & Argo CD

- **`helm_argocd.tf`**: Installs Argo CD via Helm with TLS configuration.
- **`argocd_applications.tf`**: Defines the root Argo CD Application using the App-of-Apps pattern.
- **`github.tf`**: Creates the GitHub repository and application manifest files for Argo CD.

### Utility & Examples

- **`terraform.tfvars.example`**: Sample variables file.
- **`outputs.tf`**: Defines outputs like Argo CD URL and password retrieval instructions.

## Deployment Process

See [Terraform Execution Order](docs/order_of_execution.md) for detailed resource provisioning sequence.

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

Note: The destruction process often fails with a firewall timeout error because the load balancer isn't completely destroyed and needs to be before the firewall can be removed.  The firewall is the last component to be destroyed.  If the terraform fails to completely destroy because of this, wait a few minutes and run terraform destroy again and it will clean up the remaining resources.

## GitOps Workflow with Argo CD

Terraform automatically provisions and bootstraps a GitOps repository and a sample nginx application:

- A GitHub repository named `${var.github_repo_name}` is created containing:
  - `apps/nginx.yaml`: An Argo CD Application manifest referencing the `nginx-manifests` directory
  - `nginx-manifests/nginx.yaml`: Defines a Deployment, Service, and HTTPRoute for nginx

The root Argo CD Application (`root-app`) deployed via `argocd_applications.tf` syncs the `apps` directory, which includes `nginx.yaml`. This deploys the sample nginx app accessible at `test-nginx.${var.domain_name}`.


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

1. cert-manager is installed and configured with Let's Encrypt ClusterIssuers (both staging and production)
2. DNS-01 challenge is used with Cloudflare for domain validation
3. Test subdomains (e.g., `test-argocd`, `test-nginx`) are used to avoid Let's Encrypt rate limits
4. Ingress resources are annotated to request certificates automatically
5. Certificates are stored as Kubernetes secrets and used by Traefik for TLS termination

## Important Notes

1. Both staging and production ClusterIssuers are created (`letsencrypt-staging` and `letsencrypt-prod`).
2. The default Gateway certificate is first requested via the staging issuer for initial validation and then reissued via the production issuer once DNS is live.
3. Test subdomains (e.g., `test-argocd.yourdomain.com`, `test-nginx.yourdomain.com`) are used to avoid Let's Encrypt rate limits
4. Argo CD admin password is randomly generated; retrieve it using the provided command or  you can obtain it from the terraform apply output.
5. Custom Resource Definitions (CRDs) from Helm charts may remain after `terraform destroy`
6. A wildcard DNS record is configured in Cloudflare to support all subdomains

## Security Considerations

1. API tokens and secrets are stored securely in Terraform variables and Kubernetes secrets
2. Firewall rules restrict access to the Kubernetes API and web services
3. TLS certificates are automatically managed and renewed
4. Argo CD is configured with proper TLS termination at the ingress level
