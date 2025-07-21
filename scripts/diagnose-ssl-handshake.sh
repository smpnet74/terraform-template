#!/bin/bash

# SSL Handshake Diagnostic Script for Kgateway
# This script helps diagnose SSL certificate presentation issues

set -e

KUBECONFIG_PATH="${1:-./kubeconfig}"
DOMAIN="${2:-timbersedgearb.com}"

echo "🔍 SSL Handshake Diagnostic Script for Kgateway"
echo "================================================"
echo "Using kubeconfig: $KUBECONFIG_PATH"
echo "Domain: $DOMAIN"
echo ""

# Function to run kubectl with the specified kubeconfig
kctl() {
    kubectl --kubeconfig="$KUBECONFIG_PATH" "$@"
}

# 1. Check certificate secrets
echo "1️⃣ Checking Certificate Secrets"
echo "--------------------------------"
echo "Certificate in default namespace:"
kctl get secret default-gateway-cert -n default -o yaml | grep -A2 "tls.crt\|tls.key" || echo "❌ Certificate secret not found in default namespace"

echo ""
echo "Certificate in kgateway-system namespace:"
kctl get secret default-gateway-cert -n kgateway-system -o yaml | grep -A2 "tls.crt\|tls.key" || echo "❌ Certificate secret not found in kgateway-system namespace"

# 2. Check Gateway status
echo ""
echo "2️⃣ Checking Gateway Status"
echo "---------------------------"
kctl get gateway default-gateway -n default -o yaml

echo ""
echo "Gateway conditions:"
kctl get gateway default-gateway -n default -o jsonpath='{.status.conditions}' | jq '.' || echo "No conditions found"

# 3. Check Kgateway pods
echo ""
echo "3️⃣ Checking Kgateway Pods"
echo "--------------------------"
kctl get pods -n kgateway-system -l app.kubernetes.io/name=kgateway

echo ""
echo "Kgateway pod logs (last 50 lines):"
POD_NAME=$(kctl get pods -n kgateway-system -l app.kubernetes.io/name=kgateway -o jsonpath='{.items[0].metadata.name}')
if [ -n "$POD_NAME" ]; then
    kctl logs -n kgateway-system "$POD_NAME" --tail=50 | grep -i "tls\|cert\|ssl\|error" || echo "No TLS/certificate related logs found"
else
    echo "❌ No Kgateway pods found"
fi

# 4. Check HTTPRoutes
echo ""
echo "4️⃣ Checking HTTPRoutes"
echo "-----------------------"
kctl get httproute -A -o wide

# 5. Check Gateway load balancer IP
echo ""
echo "5️⃣ Checking Gateway Load Balancer"
echo "----------------------------------"
GATEWAY_IP=$(kctl get gateway default-gateway -n default -o jsonpath='{.status.addresses[0].value}' 2>/dev/null || echo "")
if [ -n "$GATEWAY_IP" ]; then
    echo "Gateway IP: $GATEWAY_IP"
    
    # Test SSL connection directly to the IP
    echo ""
    echo "Testing SSL connection to Gateway IP:"
    timeout 10 openssl s_client -connect "$GATEWAY_IP:443" -servername "$DOMAIN" -verify_return_error < /dev/null 2>&1 | head -20 || echo "❌ SSL connection failed"
else
    echo "❌ No Gateway IP found"
fi

# 6. Check DNS resolution
echo ""
echo "6️⃣ Checking DNS Resolution"
echo "---------------------------"
echo "DNS resolution for $DOMAIN:"
dig +short "$DOMAIN" || echo "❌ DNS resolution failed"

echo ""
echo "DNS resolution for *.${DOMAIN}:"
dig +short "test.${DOMAIN}" || echo "❌ Wildcard DNS resolution failed"

# 7. Test HTTPS endpoints
echo ""
echo "7️⃣ Testing HTTPS Endpoints"
echo "---------------------------"
ENDPOINTS=(
    "zenml.${DOMAIN}"
    "grafana.${DOMAIN}"
    "kiali.${DOMAIN}"
    "policy-reporter.${DOMAIN}"
    "argo-workflows.${DOMAIN}"
)

for endpoint in "${ENDPOINTS[@]}"; do
    echo "Testing $endpoint:"
    curl -I -k --connect-timeout 5 "https://$endpoint" 2>&1 | head -3 || echo "❌ Connection failed"
    echo ""
done

# 8. Check Kgateway configuration
echo ""
echo "8️⃣ Checking Kgateway Configuration"
echo "-----------------------------------"
echo "Kgateway Helm values:"
helm --kubeconfig="$KUBECONFIG_PATH" get values kgateway -n kgateway-system || echo "❌ Could not get Helm values"

# 9. Check namespace labels for discovery
echo ""
echo "9️⃣ Checking Namespace Labels"
echo "-----------------------------"
echo "Default namespace labels:"
kctl get namespace default -o yaml | grep -A10 labels || echo "No labels found"

echo ""
echo "Kgateway-system namespace labels:"
kctl get namespace kgateway-system -o yaml | grep -A10 labels || echo "No labels found"

# 10. Summary and recommendations
echo ""
echo "🔧 Troubleshooting Summary"
echo "=========================="
echo "If SSL handshake is still failing, check:"
echo "1. Certificate secret exists in both namespaces"
echo "2. Gateway status shows 'Programmed: True'"
echo "3. Kgateway pods are running and healthy"
echo "4. HTTPRoutes are attached to the Gateway"
echo "5. DNS records point to the correct Gateway IP"
echo "6. Cloudflare DNS records are proxied (orange cloud)"
echo ""
echo "Common fixes:"
echo "- Restart Kgateway: kubectl --kubeconfig=$KUBECONFIG_PATH rollout restart deployment/kgateway -n kgateway-system"
echo "- Recreate Gateway: kubectl --kubeconfig=$KUBECONFIG_PATH delete gateway default-gateway -n default && terraform apply"
echo "- Check Kgateway logs for certificate loading errors"
echo ""
echo "✅ Diagnostic complete!"
