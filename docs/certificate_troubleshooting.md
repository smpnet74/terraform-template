# Let's Encrypt Certificate Troubleshooting Guide

This guide provides detailed steps to troubleshoot Let's Encrypt certificate issues in your Kubernetes project. Using cert-manager with the ACME protocol can lead to challenges, especially when hitting rate limits or facing DNS challenges. This document is tailored to the specifics of this project, which uses **cert-manager**, **Traefik**, and **Cloudflare** for DNS.

---

## How It Works: The Big Picture

This project automates the process of obtaining and renewing SSL/TLS certificates from Let's Encrypt. Here's a simplified overview of the process:

1.  **Ingress Creation**: When an Ingress resource (like the one for Argo CD in `kubernetes_ingress-argocd.tf`) is created with the annotation `cert-manager.io/cluster-issuer: "letsencrypt-prod"`, it signals to cert-manager that it needs a certificate.

2.  **CertificateRequest**: cert-manager creates a `CertificateRequest` resource to track the process of obtaining the certificate.

3.  **ACME Challenge**: To verify that you own the domain, Let's Encrypt requires a challenge to be completed. This project uses the `DNS-01` challenge, where cert-manager temporarily creates a `TXT` record in your Cloudflare DNS zone.

4.  **DNS Propagation**: cert-manager waits for the `TXT` record to propagate across the internet.

5.  **Verification**: Once propagated, Let's Encrypt verifies the `TXT` record. If successful, it issues the certificate.

6.  **Secret Creation**: cert-manager saves the certificate and private key in a Kubernetes Secret (e.g., `argocd-tls`).

7.  **TLS Termination**: Traefik, the Ingress controller, uses this Secret to terminate TLS and secure the connection to your application.

---

## General Workflow & Troubleshooting

### 1. Verify Ingress Annotations

**What it does:** This command lists all Ingress resources in your cluster and filters the output to show the annotations. This is the first step to ensure that your Ingress is correctly configured to use cert-manager.

```bash
kubectl get ingress -A -o yaml | grep -A 10 annotations
```

**What to look for:**
*   `kubernetes.io/ingress.class: "traefik"`: This tells Traefik to manage this Ingress.
*   `cert-manager.io/cluster-issuer: "letsencrypt-prod"`: This tells cert-manager to use the `letsencrypt-prod` issuer to get a certificate for this Ingress.

### 2. Check Certificate and Issuer

**What it does:** These commands help you verify that the `ClusterIssuer` and `Certificate` resources are correctly configured. The `ClusterIssuer` is a cluster-wide resource that defines how to obtain certificates, while the `Certificate` resource represents a specific certificate that you want to obtain.

#### List all ClusterIssuers
```bash
kubectl get clusterissuer
```
**What to look for:** You should see `letsencrypt-staging` and `letsencrypt-prod` in the output.

#### Describe specific ClusterIssuer
```bash
kubectl describe clusterissuer letsencrypt-prod
```
**What to look for:**
*   **Server URL**: Should be `https://acme-v02.api.letsencrypt.org/directory` for production.
*   **Email**: Should be your Cloudflare email address.
*   **Solver**: Should be `dns01` with the Cloudflare provider.
*   **Status**: The `status` section should show `Ready` and `True`.

#### List all Certificates
```bash
kubectl get certificates -A
```
**What to look for:** You should see a `Certificate` resource for each Ingress that you have configured to use cert-manager. The `READY` column should show `True`.

### 3. Check Certificate Status

**What it does:** This command provides detailed information about a specific `Certificate` resource, including its status, events, and any errors that may have occurred.

```bash
kubectl describe certificate <certificate-name> -n <namespace>
```

**What to look for:**
*   **Status**: The `status` section will tell you if the certificate is `Ready` or if there are any issues.
*   **Events**: The `Events` section is the most important part for troubleshooting. It will show you the steps that cert-manager has taken to obtain the certificate, and any errors that have occurred.

### 4. DNS Configuration

**What it does:** This command checks the `TXT` record that cert-manager creates in your Cloudflare DNS zone to complete the `DNS-01` challenge.

```bash
dig TXT _acme-challenge.<your-domain> +short
```

**What to look for:** You should see a long string of characters. If you don't see anything, it means that the `TXT` record has not been created or has not propagated yet.

### 5. Check ACME Challenges

**What it does:** This command lists all `Challenge` resources in your cluster. A `Challenge` resource is created for each `DNS-01` challenge that needs to be completed.

```bash
kubectl get challenges -A
```

**What to look for:** You should see a `Challenge` resource for each `Certificate` that is being processed. The `STATE` column should show `valid`. If it shows `pending` or `invalid`, you can use `kubectl describe challenge <challenge-name> -n <namespace>` to get more information.

### 6. Check Events for Clues

**What it does:** This command lists all events related to `Certificate` resources. This is a great way to get a high-level overview of what's happening with your certificates.

```bash
kubectl get events --field-selector involvedObject.kind=Certificate -A
```

**What to look for:** Look for any error messages or warnings.

---

## Common Issues and Fixes

### Rate Limits
Let's Encrypt has strict rate limits. If you are creating and deleting clusters frequently, you may hit these limits.

*   **Identify Rate Limit Errors:** You will see errors in the `Certificate` events, such as `too many certificates already issued for exact set of domains`.
*   **Solution:** During development and testing, use the `letsencrypt-staging` issuer. You can do this by changing the `cert-manager.io/cluster-issuer` annotation on your Ingress to `letsencrypt-staging`. The staging issuer has much higher rate limits.

### DNS Issues
DNS problems are a common cause of failed ACME challenges.

*   **Check DNS Propagation:** Use a tool like `nslookup` or `dig` to verify that the `TXT` record is propagating correctly.
    ```bash
    nslookup -type=TXT _acme-challenge.<your-domain>
    ```
*   **Common Fixes:**
    *   **Cloudflare API Token**: Ensure that the `cloudflare_api_token` variable in your `terraform.tfvars` is correct and has the necessary permissions to edit DNS records in your Cloudflare zone.
    *   **Cloudflare Zone ID**: Double-check that the `cloudflare_zone_id` variable is correct.

### Certificate Renewal Issues
Certificates are valid for 90 days and should be renewed automatically by cert-manager.

*   **Check Renewal Events:**
    ```bash
    kubectl get events --field-selector involvedObject.kind=CertificateRequest -A
    ```
*   **Solution:**
    *   **cert-manager Pods**: Make sure that the cert-manager pods are running in the `cert-manager` namespace: `kubectl get pods -n cert-manager`. You should see pods for `cert-manager`, `cert-manager-cainjector`, and `cert-manager-webhook`.
    *   **Firewall Rules**: Ensure that your firewall rules (in `civo_firewall-cluster.tf` and `civo_firewall-ingress.tf`) are not blocking traffic to the cert-manager webhook.

---

## Additional Resources

*   [cert-manager Documentation](https://cert-manager.io/docs/)
*   [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
*   [Traefik Documentation](https://doc.traefik.io/traefik/)