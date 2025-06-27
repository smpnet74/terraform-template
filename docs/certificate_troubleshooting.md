# Let's Encrypt Certificate Troubleshooting Guide

This guide provides detailed steps to troubleshoot Let's Encrypt certificate issues in your Kubernetes project. Using cert-manager with the ACME protocol can lead to challenges, especially when hitting rate limits or facing DNS challenges. This document is tailored to the specifics of this project, which uses **cert-manager**, **Gateway API with Kgateway**, and **Cloudflare** for DNS.

---

## How It Works: The Big Picture

This project automates the process of obtaining and renewing SSL/TLS certificates from Let's Encrypt. Here's a simplified overview of the process:

1.  **Certificate Creation**: When a Certificate resource (like the one in `kgateway_certificate.tf`) is created with a reference to a ClusterIssuer like `letsencrypt-prod`, it signals to cert-manager that it needs to obtain a certificate.

2.  **CertificateRequest**: cert-manager creates a `CertificateRequest` resource to track the process of obtaining the certificate.

3.  **ACME Challenge**: To verify that you own the domain, Let's Encrypt requires a challenge to be completed. This project uses the `DNS-01` challenge, where cert-manager temporarily creates a `TXT` record in your Cloudflare DNS zone.

4.  **DNS Propagation**: cert-manager waits for the `TXT` record to propagate across the internet.

5.  **Verification**: Once propagated, Let's Encrypt verifies the `TXT` record. If successful, it issues the certificate.

6.  **Secret Creation**: cert-manager saves the certificate and private key in a Kubernetes Secret (e.g., `default-gateway-cert`).

7.  **TLS Termination**: The Gateway API Gateway resource, implemented by Kgateway, uses this Secret to terminate TLS and secure the connection to your applications.

---

## General Workflow & Troubleshooting

### 1. Verify Gateway and HTTPRoute Configuration

**What it does:** These commands list the Gateway and HTTPRoute resources in your cluster. This is the first step to ensure that your Gateway API resources are correctly configured.

```bash
# Check Gateway configuration
kubectl get gateway -A -o yaml

# Check HTTPRoute configuration
kubectl get httproute -A -o yaml
```

**What to look for:**
*   In the Gateway resource: Check that `gatewayClassName` is set to `kgateway` and that the TLS configuration references the correct certificate secret.
*   In the HTTPRoute resources: Verify that they reference the correct Gateway in their `parentRefs` and have the correct `hostnames` configured.

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
**What to look for:** You should see a `Certificate` resource for the Gateway (e.g., `default-gateway-cert` in the `default` namespace). The `READY` column should show `True`.

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
    *   **Firewall Rules**: Ensure that your firewall rules (in `civo_firewall-cluster.tf`) are not blocking traffic to the cert-manager webhook.

---

## Additional Resources

*   [cert-manager Documentation](https://cert-manager.io/docs/)
*   [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
*   [Gateway API Documentation](https://gateway-api.sigs.k8s.io/)
*   [Kgateway Documentation](https://kgateway.dev/)

## All-in-One Troubleshooting Script

Below is a comprehensive bash script that runs all the troubleshooting commands in sequence. You can copy this script, save it as `cert-troubleshoot.sh`, make it executable with `chmod +x cert-troubleshoot.sh`, and run it to quickly diagnose certificate issues.

```bash
#!/bin/bash

# Certificate Troubleshooting Script for Gateway API and cert-manager
# This script runs all the commands from the troubleshooting guide in sequence

# Set colors for better readability
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
RED="\033[0;31m"
NC="\033[0m" # No Color

echo -e "${BLUE}=========================================================${NC}"
echo -e "${YELLOW}Certificate Troubleshooting for Gateway API and cert-manager${NC}"
echo -e "${BLUE}=========================================================${NC}"

# 1. Check Gateway and HTTPRoute Configuration
echo -e "\n${GREEN}1. Checking Gateway Configuration...${NC}"
kubectl get gateway -A
echo -e "\n${YELLOW}Gateway Details:${NC}"
kubectl get gateway -A -o yaml | grep -E 'name:|gatewayClassName:|tls:' -A 5

echo -e "\n${GREEN}Checking HTTPRoute Configuration...${NC}"
kubectl get httproute -A
echo -e "\n${YELLOW}HTTPRoute Details:${NC}"
kubectl get httproute -A -o yaml | grep -E 'name:|parentRefs:|hostnames:' -A 5

# 2. Check Certificate and Issuer
echo -e "\n${GREEN}2. Checking ClusterIssuers...${NC}"
kubectl get clusterissuer

echo -e "\n${YELLOW}Let's Encrypt Production Issuer Details:${NC}"
kubectl describe clusterissuer letsencrypt-prod

echo -e "\n${GREEN}Checking Certificates...${NC}"
kubectl get certificates -A

echo -e "\n${YELLOW}Certificate Details:${NC}"
CERTS=$(kubectl get certificates -A -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{"\n"}{end}')
for CERT in $CERTS; do
  read -r NAMESPACE NAME <<< "$CERT"
  echo -e "\n${BLUE}Certificate: $NAME in namespace $NAMESPACE${NC}"
  kubectl describe certificate "$NAME" -n "$NAMESPACE"
done

# 3. Check Certificate Status and Events
echo -e "\n${GREEN}3. Checking Certificate Events...${NC}"
kubectl get events --field-selector involvedObject.kind=Certificate -A

# 4. Check DNS Configuration
echo -e "\n${GREEN}4. Checking DNS Configuration...${NC}"
echo -e "${YELLOW}Note: You need to manually run 'dig TXT _acme-challenge.<your-domain> +short'${NC}"
echo -e "${YELLOW}Replace <your-domain> with your actual domain name${NC}"

# 5. Check ACME Challenges
echo -e "\n${GREEN}5. Checking ACME Challenges...${NC}"
kubectl get challenges -A

CHALLENGES=$(kubectl get challenges -A -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{"\n"}{end}')
for CHALLENGE in $CHALLENGES; do
  if [ -n "$CHALLENGE" ]; then
    read -r NAMESPACE NAME <<< "$CHALLENGE"
    echo -e "\n${BLUE}Challenge: $NAME in namespace $NAMESPACE${NC}"
    kubectl describe challenge "$NAME" -n "$NAMESPACE"
  fi
done

# 6. Check CertificateRequests
echo -e "\n${GREEN}6. Checking CertificateRequests...${NC}"
kubectl get certificaterequests -A

echo -e "\n${YELLOW}CertificateRequest Events:${NC}"
kubectl get events --field-selector involvedObject.kind=CertificateRequest -A

# 7. Check cert-manager pods
echo -e "\n${GREEN}7. Checking cert-manager pods...${NC}"
kubectl get pods -n cert-manager

# 8. Check Gateway service
echo -e "\n${GREEN}8. Checking Gateway service...${NC}"
kubectl get service -n default default-gateway -o wide

# 9. Check certificate secrets
echo -e "\n${GREEN}9. Checking certificate secrets...${NC}"
kubectl get secrets -A | grep -E 'default-gateway-cert|tls'

echo -e "\n${BLUE}=========================================================${NC}"
echo -e "${YELLOW}Troubleshooting Complete!${NC}"
echo -e "${BLUE}=========================================================${NC}"
```

This script will:
1. Check Gateway and HTTPRoute configurations
2. Verify ClusterIssuers and Certificates
3. Display Certificate events
4. Remind you to check DNS configuration
5. Check ACME Challenges
6. Check CertificateRequests and their events
7. Verify cert-manager pods are running
8. Check the Gateway service
9. List certificate-related secrets

The output is color-coded for better readability.
