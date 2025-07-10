# Kgateway Troubleshooting Guide

This guide provides detailed steps to troubleshoot Kgateway issues in your Kubernetes project. Gateway API with Kgateway can sometimes present challenges related to configuration, routing, and integration with other components. This document is tailored to the specifics of this project, which uses **Gateway API v1.2.1**, **Kgateway v2.0.3**, and integrates with **Cloudflare Origin Certificates** for TLS.

---

## How It Works: The Big Picture

This project implements the Gateway API using Kgateway as the controller with a **dual CRD architecture**. Here's a simplified overview of the architecture:

1. **Standard Gateway API CRDs** (v1.2.1): The foundation providing vendor-neutral resources like Gateway, HTTPRoute, and GatewayClass.

2. **Kgateway-Specific CRDs** (v2.0.3): Vendor-specific extensions providing advanced features like TrafficPolicies and Backends.

3. **Kgateway Controller**: An Envoy-based implementation that watches both standard and vendor-specific resources.

4. **Gateway Resource**: Defines the entry point for traffic into the cluster, specifying listeners, ports, and TLS configuration.

5. **HTTPRoute Resources**: Define how HTTP traffic is routed to backend services based on hostnames, paths, and other criteria.

6. **TLS Termination**: Handled by the Gateway using Cloudflare Origin Certificates.

---

## Part 1: Installation and Component Verification

### 1.1. Verify Kgateway Installation

**What it does:** These commands check if Kgateway and its components are properly installed in the cluster.

```bash
# Check Kgateway namespace
kubectl get namespace kgateway-system

# Check Kgateway pods
kubectl get pods -n kgateway-system

# Check Kgateway deployments
kubectl get deployments -n kgateway-system

# Check Kgateway services
kubectl get services -n kgateway-system
```

**What to look for:**
* All pods should be in the `Running` state
* Deployments should show desired replicas matching available replicas
* Services should be properly created

### 1.2. Check Dual CRD Installation

**What it does:** These commands verify that both standard Gateway API and Kgateway-specific CRDs are properly installed.

```bash
# Check Standard Gateway API CRDs (should show v1.2.1)
kubectl get crds | grep gateway.networking.k8s.io

# Check Kgateway-specific CRDs (should show v2.0.3 features)
kubectl get crds | grep gateway.kgateway.dev

# Verify Gateway API version
kubectl get crd gateways.gateway.networking.k8s.io -o jsonpath='{.metadata.annotations.gateway\.networking\.k8s\.io/bundle-version}'

# Verify Kgateway CRDs Helm installation
helm list -n kgateway-system
```

**What to look for:**

**Standard Gateway API CRDs:**
* `gateways.gateway.networking.k8s.io` - Core Gateway resource
* `httproutes.gateway.networking.k8s.io` - HTTP routing rules
* `referencegrants.gateway.networking.k8s.io` - Cross-namespace access control
* `gatewayclasses.gateway.networking.k8s.io` - Gateway implementation configuration
* Bundle version should show `v1.2.1`

**Kgateway-Specific CRDs:**
* `backends.gateway.kgateway.dev` - Advanced backend configuration
* `trafficpolicies.gateway.kgateway.dev` - Traffic management policies
* `gatewayparameters.gateway.kgateway.dev` - Kgateway-specific parameters
* `httplistenerpolicies.gateway.kgateway.dev` - HTTP listener policies
* Helm chart should show `kgateway-crds-v2.0.3`

**Common Issues:**
* **Missing Standard CRDs**: Check if `null_resource.gateway_api_crds` executed successfully
* **Missing Kgateway CRDs**: Check if `helm_release.kgateway_crds` deployed successfully  
* **Version Mismatch**: Verify both CRD sets have the correct versions
* **Installation Order**: Kgateway CRDs should install after standard Gateway API CRDs

### 1.3. Verify Gateway Resources

**What it does:** These commands check the Gateway resources in your cluster.

```bash
# List all Gateways
kubectl get gateway -A

# Describe the default Gateway
kubectl describe gateway default-gateway -n default
```

**What to look for:**
* The Gateway should be present and have an `Accepted` condition
* The `gatewayClassName` should be `kgateway`
* The listeners should be properly configured for HTTP (port 80) and HTTPS (port 443)
* For HTTPS listeners, check that the TLS configuration references the correct certificate

### 1.4. Check Gateway Class

**What it does:** This command verifies the GatewayClass that defines the implementation.

```bash
# List GatewayClasses
kubectl get gatewayclass

# Describe the Kgateway GatewayClass
kubectl describe gatewayclass kgateway
```

**What to look for:**
* The GatewayClass should be present and have an `Accepted` condition
* The controller should be `gateway.kgateway.dev/controller`

### 1.5. Check Gateway Service

**What it does:** This command checks the Kubernetes Service created for the Gateway.

```bash
# Get the Gateway service
kubectl get service default-gateway -n default
```

**What to look for:**
* The service should have an external IP assigned
* The service should have ports 80 and 443 exposed
* The service type should be `LoadBalancer`

---

## Part 2: Routing and Connectivity Issues

### 2.1. Check HTTPRoute Resources

**What it does:** These commands examine the HTTPRoute resources that define how traffic is routed to backend services.

```bash
# List all HTTPRoutes
kubectl get httproute -A

# Describe a specific HTTPRoute (replace with your route name)
kubectl describe httproute argocd-server-route -n argocd
```

**What to look for:**
* The HTTPRoute should reference the correct Gateway in its `parentRefs`
* The `hostnames` should match your domain configuration
* The `backendRefs` should point to valid services with correct ports
* Check for any status conditions that might indicate issues

### 2.2. Verify Backend Services

**What it does:** This command checks if the backend services referenced by your HTTPRoutes exist and are properly configured.

```bash
# List services in the namespace (replace with your namespace)
kubectl get services -n argocd

# Describe a specific service
kubectl describe service argocd-server -n argocd
```

**What to look for:**
* The service should exist in the correct namespace
* The service should have the correct port configuration
* The service should have endpoints (pods) available

### 2.3. Check Kgateway Logs

**What it does:** These commands examine the logs from Kgateway pods to identify any errors or issues.

```bash
# Get Kgateway pod names
KGATEWAY_PODS=$(kubectl get pods -n kgateway-system -l app=kgateway -o jsonpath='{.items[*].metadata.name}')

# Check logs for each pod
for POD in $KGATEWAY_PODS; do
  echo "\nLogs for $POD:\n"
  kubectl logs $POD -n kgateway-system | grep -i error
done
```

**What to look for:**
* Error messages related to configuration issues
* TLS/certificate errors
* Connection problems with backend services
* Resource validation errors

### 2.4. Test Connectivity

**What it does:** These commands help test connectivity to your Gateway from both inside and outside the cluster.

```bash
# Get Gateway IP
GATEWAY_IP=$(kubectl get service default-gateway -n default -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Test HTTP connectivity
echo "Testing HTTP connectivity to $GATEWAY_IP"
curl -v -H "Host: your-domain.com" http://$GATEWAY_IP

# Test HTTPS connectivity
echo "Testing HTTPS connectivity to $GATEWAY_IP"
curl -v -k -H "Host: your-domain.com" https://$GATEWAY_IP
```

**What to look for:**
* Successful connection to the Gateway
* Proper TLS handshake for HTTPS
* Correct routing to the backend service
* Any error messages in the verbose output

### 2.5. Check DNS Resolution

**What it does:** This command verifies that your domain names resolve to the correct Gateway IP address.

```bash
# Check DNS resolution
dig +short your-domain.com
dig +short *.your-domain.com
```

**What to look for:**
* The DNS records should resolve to the Gateway's external IP
* Both the root domain and wildcard domain should resolve correctly

### 2.6. Verify Envoy Configuration

**What it does:** This command examines the Envoy configuration generated by Kgateway.

```bash
# Get Kgateway pod name
KGATEWAY_POD=$(kubectl get pods -n kgateway-system -l app=kgateway -o jsonpath='{.items[0].metadata.name}')

# Check Envoy config dump
kubectl exec -n kgateway-system $KGATEWAY_POD -- curl -s localhost:19000/config_dump > envoy_config_dump.json

# Look for listeners and routes
grep -A 10 "route_config_name" envoy_config_dump.json
```

**What to look for:**
* Properly configured listeners for your domains
* Route configurations matching your HTTPRoutes
* Virtual hosts and routes for your services

---

## Part 3: Common Issues and Solutions

### 3.1. Certificate Integration Issues

**Problem:** Gateway cannot find or use the certificate referenced in the TLS configuration.

**Troubleshooting:**
```bash
# Check if the certificate secret exists
kubectl get secret default-gateway-cert -n default

# Check certificate status
kubectl describe certificate default-gateway-cert -n default

# Verify the Gateway is referencing the correct certificate
kubectl get gateway default-gateway -n default -o yaml | grep -A 10 certificateRefs
```

**Solution:**
* Ensure the Cloudflare Origin Certificate is properly loaded as a Kubernetes secret
* Verify the certificate secret name matches what's referenced in the Gateway (`default-gateway-cert`)
* Check that the certificate secret is in the same namespace as the Gateway (`default`)
* Verify the secret contains both `tls.crt` and `tls.key` data

### 3.2. Routing Issues

**Problem:** Traffic is not being routed to the correct backend service.

**Troubleshooting:**
```bash
# Check if the HTTPRoute is properly configured
kubectl get httproute -A -o yaml | grep -E 'hostnames:|parentRefs:|backendRefs:' -A 5

# Verify the backend service exists and has endpoints
kubectl get endpoints -A | grep your-service-name
```

**Solution:**
* Ensure the HTTPRoute references the correct Gateway in its `parentRefs`
* Verify the `hostnames` match your domain configuration
* Check that the `backendRefs` point to valid services with correct ports
* Ensure the backend service has endpoints (pods) available

### 3.3. Gateway Not Ready

**Problem:** The Gateway resource shows a status of not ready or not accepted.

**Troubleshooting:**
```bash
# Check Gateway status
kubectl get gateway default-gateway -n default -o yaml | grep -A 10 status

# Verify Kgateway controller is running
kubectl get pods -n kgateway-system
```

**Solution:**
* Ensure the Kgateway controller pods are running
* Check for any errors in the Kgateway controller logs
* Verify the Gateway is using the correct `gatewayClassName`
* Check for any resource constraints or configuration issues

### 3.4. TLS Handshake Issues

**Problem:** HTTPS connections fail with TLS handshake errors.

**Troubleshooting:**
```bash
# Test TLS handshake
openssl s_client -connect your-domain.com:443 -servername your-domain.com

# Check certificate validity
echo | openssl s_client -connect your-domain.com:443 -servername your-domain.com 2>/dev/null | openssl x509 -noout -dates
```

**Solution:**
* Ensure the Cloudflare Origin Certificate is valid and not expired
* Verify the certificate covers the domain being accessed (wildcard: `*.yourdomain.com`)
* Check that the certificate secret `default-gateway-cert` is properly referenced in the Gateway
* Ensure Cloudflare SSL/TLS mode is set to "Full" for end-to-end encryption
* Verify the certificate files were properly loaded from the `/certs` directory

### 3.5. Dual CRD Installation Issues

**Problem:** Issues with the dual CRD architecture where standard Gateway API CRDs conflict with Kgateway-specific CRDs.

**Troubleshooting:**
```bash
# Check if both CRD sets are installed
echo "=== Standard Gateway API CRDs ===" 
kubectl get crd | grep gateway.networking.k8s.io

echo "=== Kgateway-Specific CRDs ==="
kubectl get crd | grep gateway.kgateway.dev

# Verify installation order and timing
kubectl get events --sort-by=.metadata.creationTimestamp | grep -i crd

# Check for CRD conflicts or overlaps
kubectl describe crd gateways.gateway.networking.k8s.io | grep -A 5 -B 5 "Conflict\|Error"

# Verify Terraform resource status
terraform show | grep -A 10 -B 5 "gateway_api_crds\|kgateway_crds"
```

**Solution:**
* **Installation Order**: Ensure standard Gateway API CRDs install before Kgateway CRDs
* **Version Compatibility**: Verify Gateway API v1.2.1 is compatible with Kgateway v2.0.3
* **Terraform Dependencies**: Check that `time_sleep.wait_for_gateway_crds` provides adequate delay
* **Resource Conflicts**: Remove any existing CRDs before reinstalling if conflicts occur
* **Helm Status**: Verify `helm_release.kgateway_crds` deployed successfully without errors

**Common Fixes:**
```bash
# If standard CRDs are missing, reinstall them
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml

# If Kgateway CRDs are missing, reinstall via Helm
helm uninstall kgateway-crds -n kgateway-system
helm install kgateway-crds oci://cr.kgateway.dev/kgateway-dev/charts/kgateway-crds --version v2.0.3 -n kgateway-system --create-namespace

# Verify both sets are working together
kubectl api-resources | grep gateway
```

### 3.6. Future AI Gateway Integration

**Problem:** Preparing for AI Gateway integration for LLM traffic.

**Considerations:**
* AI Gateway will use the same Gateway API infrastructure but with specialized routes and backends
* May require additional configuration for rate limiting, authentication, and authorization
* Will need to ensure proper routing based on traffic type (web vs. LLM)

**Preparation:**
* Ensure current Gateway API implementation is stable and well-understood
* Plan for separate HTTPRoutes for AI traffic with appropriate security measures
* Consider namespace isolation for AI components

## All-in-One Troubleshooting Script

Below is a comprehensive bash script that runs all the troubleshooting commands in sequence. You can copy this script, save it as `kgateway-troubleshoot.sh`, make it executable with `chmod +x kgateway-troubleshoot.sh`, and run it to quickly diagnose Kgateway issues.

```bash
#!/bin/bash

# Kgateway Troubleshooting Script
# This script runs all the commands from the troubleshooting guide in sequence

# Set colors for better readability
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
RED="\033[0;31m"
NC="\033[0m" # No Color

echo -e "${BLUE}=========================================================${NC}"
echo -e "${YELLOW}Kgateway Troubleshooting${NC}"
echo -e "${BLUE}=========================================================${NC}"

# Part 1: Installation and Component Verification
echo -e "\n${GREEN}1. Installation and Component Verification${NC}"

echo -e "\n${YELLOW}1.1. Verifying Kgateway Installation...${NC}"
echo -e "\n${BLUE}Kgateway Namespace:${NC}"
kubectl get namespace kgateway-system

echo -e "\n${BLUE}Kgateway Pods:${NC}"
kubectl get pods -n kgateway-system

echo -e "\n${BLUE}Kgateway Deployments:${NC}"
kubectl get deployments -n kgateway-system

echo -e "\n${BLUE}Kgateway Services:${NC}"
kubectl get services -n kgateway-system

echo -e "\n${YELLOW}1.2. Checking Gateway API CRDs...${NC}"
kubectl get crds | grep gateway.networking.k8s.io

echo -e "\n${YELLOW}1.3. Verifying Gateway Resources...${NC}"
echo -e "\n${BLUE}Gateway List:${NC}"
kubectl get gateway -A

echo -e "\n${BLUE}Default Gateway Details:${NC}"
kubectl describe gateway default-gateway -n default

echo -e "\n${YELLOW}1.4. Checking Gateway Class...${NC}"
echo -e "\n${BLUE}GatewayClass List:${NC}"
kubectl get gatewayclass

echo -e "\n${BLUE}Kgateway GatewayClass Details:${NC}"
kubectl describe gatewayclass kgateway

echo -e "\n${YELLOW}1.5. Checking Gateway Service...${NC}"
kubectl get service default-gateway -n default -o wide

# Part 2: Routing and Connectivity Issues
echo -e "\n${GREEN}2. Routing and Connectivity Issues${NC}"

echo -e "\n${YELLOW}2.1. Checking HTTPRoute Resources...${NC}"
echo -e "\n${BLUE}HTTPRoute List:${NC}"
kubectl get httproute -A

HTTPROUTES=$(kubectl get httproute -A -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{"\n"}{end}')
for ROUTE in $HTTPROUTES; do
  if [ -n "$ROUTE" ]; then
    read -r NAMESPACE NAME <<< "$ROUTE"
    echo -e "\n${BLUE}HTTPRoute: $NAME in namespace $NAMESPACE${NC}"
    kubectl describe httproute "$NAME" -n "$NAMESPACE" | grep -E 'Hostname|Parent|Backend|Status' -A 3
  fi
done

echo -e "\n${YELLOW}2.2. Verifying Backend Services...${NC}"
# Get all namespaces with HTTPRoutes
NAMESPACES=$(kubectl get httproute -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\n"}{end}' | sort -u)
for NS in $NAMESPACES; do
  echo -e "\n${BLUE}Services in namespace $NS:${NC}"
  kubectl get services -n "$NS"
done

echo -e "\n${YELLOW}2.3. Checking Kgateway Logs...${NC}"
KGATEWAY_PODS=$(kubectl get pods -n kgateway-system -l app=kgateway -o jsonpath='{.items[*].metadata.name}')
for POD in $KGATEWAY_PODS; do
  echo -e "\n${BLUE}Recent errors in logs for $POD:${NC}"
  kubectl logs --tail=50 "$POD" -n kgateway-system | grep -i error
done

echo -e "\n${YELLOW}2.4. Testing Connectivity...${NC}"
GATEWAY_IP=$(kubectl get service default-gateway -n default -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo -e "\n${BLUE}Gateway IP: $GATEWAY_IP${NC}"
echo -e "${YELLOW}Note: To test connectivity, manually run:${NC}"
echo -e "curl -v -H \"Host: your-domain.com\" http://$GATEWAY_IP"
echo -e "curl -v -k -H \"Host: your-domain.com\" https://$GATEWAY_IP"

echo -e "\n${YELLOW}2.5. Checking DNS Resolution...${NC}"
echo -e "${YELLOW}Note: To check DNS resolution, manually run:${NC}"
echo -e "dig +short your-domain.com"
echo -e "dig +short *.your-domain.com"

echo -e "\n${YELLOW}2.6. Verifying Envoy Configuration...${NC}"
KGATEWAY_POD=$(kubectl get pods -n kgateway-system -l app=kgateway -o jsonpath='{.items[0].metadata.name}')
if [ -n "$KGATEWAY_POD" ]; then
  echo -e "\n${BLUE}Saving Envoy config dump to envoy_config_dump.json...${NC}"
  kubectl exec -n kgateway-system "$KGATEWAY_POD" -- curl -s localhost:19000/config_dump > envoy_config_dump.json
  echo -e "\n${BLUE}Checking for route configurations:${NC}"
  grep -A 5 "route_config_name" envoy_config_dump.json | head -20
  echo -e "\n${YELLOW}Full config dump saved to envoy_config_dump.json${NC}"
fi

# Part 3: Certificate Integration
echo -e "\n${GREEN}3. Certificate Integration${NC}"

echo -e "\n${YELLOW}3.1. Checking Certificate Secret...${NC}"
kubectl get secret default-gateway-cert -n default

echo -e "\n${YELLOW}3.2. Checking Certificate Status...${NC}"
kubectl describe certificate default-gateway-cert -n default

echo -e "\n${YELLOW}3.3. Verifying Gateway Certificate Reference...${NC}"
kubectl get gateway default-gateway -n default -o yaml | grep -A 10 certificateRefs

echo -e "\n${BLUE}=========================================================${NC}"
echo -e "${YELLOW}Troubleshooting Complete!${NC}"
echo -e "${BLUE}=========================================================${NC}"
```

This script will:
1. Verify Kgateway installation and components
2. Check Gateway API CRDs and resources
3. Examine HTTPRoute configurations
4. Verify backend services
5. Check Kgateway logs for errors
6. Provide commands for connectivity testing
7. Examine Envoy configuration
8. Verify certificate integration

The output is color-coded for better readability.
