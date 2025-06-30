# Cloudflare Origin Certificate Architecture & Troubleshooting Guide

This document outlines the architecture, configuration, and troubleshooting procedures for the Kubernetes GitOps project using **Cloudflare Origin Certificates**, **Gateway API with Kgateway**, and **Terraform** for infrastructure management.

## Architecture Overview

### Certificate Flow Architecture

```
┌─────────────────┐     HTTPS     ┌─────────────────┐     HTTPS     ┌─────────────────┐
│                 │  (Public CA)  │                 │  (Origin CA)  │                 │
│  End User's     │◄────────────► │   Cloudflare    │◄────────────► │   Kubernetes    │
│  Web Browser    │               │   Edge Proxy    │               │   Cluster       │
└─────────────────┘               └─────────────────┘               └─────────────────┘
                                                                           │
                                                                           │
                                                                    ┌──────▼───────┐
                                                                    │  Kgateway    │
                                                                    │  Ingress     │
                                                                    └──────────────┘
                                                                           │
                                                                           │
                                                                    ┌──────▼───────┐
                                                                    │  Services    │
                                                                    │  (ArgoCD,    │
                                                                    │   Nginx)     │
                                                                    └──────────────┘
```

### Security Model

1. **End-to-End Encryption**:
   - Traffic between users and Cloudflare is secured with Cloudflare's trusted public certificates
   - Traffic between Cloudflare and your Kubernetes cluster is secured with Cloudflare Origin Certificates

2. **Certificate Trust Chain**:
   - Cloudflare Origin Certificates are trusted by Cloudflare but not by public browsers
   - This is why Cloudflare proxying (orange cloud) must be enabled for all DNS records

## Configuration Components

### 1. Certificate Files (`/certs` directory)

- **tls.crt**: The Cloudflare Origin Certificate
- **tls.key**: The private key for the certificate
- These files are excluded from Git via `.gitignore`

#### Obtaining Cloudflare Origin Certificates

1. **Log into Cloudflare Dashboard**:
   - Navigate to https://dash.cloudflare.com
   - Select your domain (e.g., `timbersedgearb.com`)

2. **Generate Origin Certificate**:
   - Go to **SSL/TLS** > **Origin Server**
   - Click **Create Certificate**
   - Select the following options:
     - **Private key type**: RSA (2048)
     - **Hostnames**: Your domain and wildcard (e.g., `timbersedgearb.com, *.timbersedgearb.com`)
     - **Validity**: Choose desired duration (15 years recommended)

3. **Save Certificate Files**:
   - After generating, you'll see two text boxes:
     - The top box contains the **Origin Certificate** (save as `tls.crt`)
     - The bottom box contains the **Private Key** (save as `tls.key`)
   - Click the **Copy** buttons and save both files

4. **Create Local Directory and Files**:
   ```bash
   # Create the certs directory in your Terraform project
   mkdir -p /path/to/terraform-template/certs
   
   # Create the certificate files
   nano /path/to/terraform-template/certs/tls.crt
   # Paste the Origin Certificate content and save
   
   nano /path/to/terraform-template/certs/tls.key
   # Paste the Private Key content and save
   ```

5. **Verify Certificate Files**:
   ```bash
   # Verify the certificate content
   openssl x509 -in /path/to/terraform-template/certs/tls.crt -text -noout
   ```

#### Configuring Cloudflare DNS and SSL Settings

1. **Configure SSL/TLS Mode**:
   - In Cloudflare dashboard, go to **SSL/TLS** > **Overview**
   - Set SSL/TLS encryption mode to **Full (strict)** or **Full**
     - **Full (strict)** validates the origin certificate (recommended)
     - **Full** encrypts but doesn't validate the origin certificate

2. **Ensure DNS Records are Proxied**:
   - Go to **DNS** > **Records**
   - For each A record pointing to your Kubernetes cluster:
     - Make sure the cloud icon is **Orange** (proxied), not gray
     - If it's gray, click it to toggle to orange
   - This is critical for the certificate trust chain to work properly

3. **Configure Edge Certificates**:
   - Go to **SSL/TLS** > **Edge Certificates**
   - Enable **Always Use HTTPS** to redirect HTTP to HTTPS
   - Set minimum TLS version to TLS 1.2 for better security

### 2. Kubernetes TLS Secret (`kgateway_certificate.tf`)

```hcl
resource "kubernetes_secret" "cloudflare_origin_cert" {
  metadata {
    name      = "default-gateway-cert"
    namespace = "default"
  }
  type = "kubernetes.io/tls"
  data = {
    "tls.crt" = file("${path.module}/certs/tls.crt")
    "tls.key" = file("${path.module}/certs/tls.key")
  }
}
```

### 3. Gateway API Configuration (`kgateway_api.tf`)

```hcl
resource "kubectl_manifest" "default_gateway" {
  yaml_body = <<-YAML
  apiVersion: gateway.networking.k8s.io/v1
  kind: Gateway
  metadata:
    name: default-gateway
    namespace: default
  spec:
    gatewayClassName: kgateway
    listeners:
    - name: http
      port: 80
      protocol: HTTP
    - name: https
      port: 443
      protocol: HTTPS
      tls:
        certificateRefs:
        - name: default-gateway-cert
          kind: Secret
  YAML
}
```

### 4. Cloudflare DNS Configuration (`cloudflare_dns.tf`)

```hcl
resource "cloudflare_dns_record" "root" {
  zone_id = var.cloudflare_zone_id
  name    = var.domain_name
  content = local.gateway_lb_ip
  type    = "A"
  proxied = true  # Critical for certificate trust
  ttl     = 1
}

resource "cloudflare_dns_record" "wildcard" {
  zone_id = var.cloudflare_zone_id
  name    = "*"
  content = local.gateway_lb_ip
  type    = "A"
  proxied = true  # Critical for certificate trust
  ttl     = 1
}
```

### 5. ArgoCD HTTPRoute Configuration (`kubernetes_ingress-argocd.tf`)

```hcl
resource "kubectl_manifest" "argocd_httproute" {
  yaml_body = <<-YAML
  apiVersion: gateway.networking.k8s.io/v1
  kind: HTTPRoute
  metadata:
    name: argocd-server
    namespace: argocd
  spec:
    hostnames:
    - "test-argocd.${var.domain_name}"
    parentRefs:
    - name: default-gateway
      namespace: default
    rules:
    - backendRefs:
      - name: argocd-server
        port: 80
        kind: Service
  YAML
  depends_on = [
    helm_release.argocd,
    kubernetes_secret.cloudflare_origin_cert
  ]
}
```

## How It Works: The Big Picture

1. **Certificate Acquisition**:
   - Generate Cloudflare Origin Certificate in Cloudflare dashboard
   - Save certificate and key to local `/certs` directory
   - Terraform creates a Kubernetes TLS secret with these files

2. **TLS Termination**:
   - Kgateway Gateway loads the TLS secret
   - Handles HTTPS connections on port 443
   - Forwards decrypted traffic to backend services

3. **DNS and Proxying**:
   - Cloudflare DNS records point to Kubernetes Gateway load balancer IP
   - Proxied setting (orange cloud) ensures traffic passes through Cloudflare
   - Cloudflare handles public-facing TLS with trusted certificates

4. **Traffic Flow**:
   - User → Cloudflare (HTTPS with public CA) → Kubernetes (HTTPS with Origin CA) → Service

## Key Advantages Over Let's Encrypt

1. **No Rate Limits**: Cloudflare Origin Certificates don't have the strict rate limits of Let's Encrypt
2. **Longer Validity**: Up to 15 years vs 90 days for Let's Encrypt
3. **No Challenge Complexity**: No need for DNS-01 or HTTP-01 challenge validation
4. **Simplified Management**: No cert-manager dependency or renewal concerns
5. **Performance**: Cloudflare's global CDN and security features

## Troubleshooting

### One-Liner Diagnostic Script

```bash
echo "=== CERTIFICATE DIAGNOSTICS ===" && kubectl get secret default-gateway-cert -n default -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -text | grep -E 'Subject:|DNS:|Not After' && echo -e "\n=== GATEWAY STATUS ===" && kubectl get gateway default-gateway -n default -o yaml | grep -A10 "status:" && echo -e "\n=== KGATEWAY PODS ===" && kubectl get pods -n kgateway-system && echo -e "\n=== HTTPROUTE STATUS ===" && kubectl get httproute -A -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{" "}{range .status.parents[*]}{.conditions[?(@.type=="Accepted")].status}{" "}{end}{"\n"}{end}' && echo -e "\n=== CLOUDFLARE PROXY CHECK ===" && echo "Run: curl -sI https://test-argocd.${DOMAIN} | grep -i 'cf-ray'"
```

### Common Issues and Solutions

#### 1. "Not Secure" Warning in Browser

**Symptoms**:
- Browser shows "Not Secure" or certificate errors
- Certificate details show "Cloudflare Origin Certificate"

**Cause**:
- DNS records not proxied through Cloudflare (gray cloud instead of orange)

**Solution**:
- Ensure `proxied = true` in `cloudflare_dns.tf`
- Verify orange cloud icon in Cloudflare dashboard
- Run `terraform apply -target=cloudflare_dns_record.root -target=cloudflare_dns_record.wildcard`

#### 2. Gateway Cannot Load Certificate

**Symptoms**:
- Gateway status shows `ResolvedRefs: False`
- Error message about invalid or missing certificate

**Cause**:
- Certificate files missing or incorrect
- Kubernetes secret not created properly

**Solution**:
- Verify certificate files exist in `/certs` directory
- Check secret was created: `kubectl get secret default-gateway-cert -n default`
- Recreate secret if needed: `terraform apply -target=kubernetes_secret.cloudflare_origin_cert`

#### 3. Cannot Access Services

**Symptoms**:
- Services like ArgoCD unreachable
- No error in browser, just timeout

**Cause**:
- HTTPRoute not properly configured
- Gateway not properly programmed

**Solution**:
- Check HTTPRoute status: `kubectl get httproute -A`
- Verify Gateway status: `kubectl get gateway default-gateway -n default -o yaml`
- Check Kgateway pods: `kubectl get pods -n kgateway-system`
- Verify DNS resolves to correct IP: `dig +short test-argocd.yourdomain.com`

## Terraform File Relationships

| File | Purpose | Components |
|------|---------|------------|
| `kgateway_certificate.tf` | Certificate configuration | Kubernetes TLS secret from local files |
| `kgateway_api.tf` | Gateway API setup | Gateway resource, Kgateway Helm release |
| `cloudflare_dns.tf` | DNS configuration | Root and wildcard DNS records with proxying |
| `kubernetes_ingress-argocd.tf` | Service routing | HTTPRoute for ArgoCD service |
| `helm_argocd.tf` | ArgoCD deployment | ArgoCD Helm release |

## Initial Setup Process

For someone using this Terraform configuration for the first time, follow these steps to set up the certificate infrastructure:

1. **Prerequisites**:
   - Cloudflare account with your domain added
   - Terraform installed locally
   - `kubectl` configured to access your Kubernetes cluster
   - Cloudflare API token with appropriate permissions

2. **Certificate Setup**:
   - Follow the steps in [Obtaining Cloudflare Origin Certificates](#obtaining-cloudflare-origin-certificates) section
   - Create the `certs` directory in your project root: `mkdir -p ./certs`
   - Save the certificate and key files as `./certs/tls.crt` and `./certs/tls.key`

3. **Terraform Configuration**:
   - Copy `terraform.tfvars.example` to `terraform.tfvars`
   - Fill in your Cloudflare API token, zone ID, and domain name
   - Ensure your Kubernetes cluster is provisioned or configuration is ready

4. **Apply Terraform Configuration**:
   ```bash
   # Initialize Terraform
   terraform init
   
   # Apply the configuration
   terraform apply
   ```

5. **Verify Configuration**:
   - Run the diagnostic script from the [Troubleshooting](#troubleshooting) section
   - Check Cloudflare dashboard to ensure DNS records are proxied (orange cloud)
   - Test accessing your services via HTTPS

## Certificate Renewal Procedure

1. Generate new Cloudflare Origin Certificate in Cloudflare dashboard
2. Save new certificate and key to `/certs` directory
3. Run `terraform apply -target=kubernetes_secret.cloudflare_origin_cert`
4. Verify Gateway picks up new certificate: `kubectl get gateway default-gateway -n default -o yaml`

## Security Best Practices

1. Never commit certificate files to Git (ensured by `.gitignore`)
2. Use Cloudflare's security features (WAF, rate limiting, etc.)
3. Consider implementing Cloudflare Access for additional authentication
4. Rotate certificates according to your security policy
5. Monitor certificate expiration (Cloudflare Origin Certificates can be valid for up to 15 years)
