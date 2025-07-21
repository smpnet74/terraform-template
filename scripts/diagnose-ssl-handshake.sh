#!/bin/bash

# SSL Handshake Diagnostic Script for Kgateway
# This script helps diagnose SSL certificate presentation issues

# --- Color Codes ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

set -e

KUBECONFIG_PATH="${1:-./kubeconfig}"
DOMAIN="${2:-timbersedgearb.com}"

echo -e "${GREEN}🔍 SSL Handshake Diagnostic Script for Kgateway${NC}"
echo -e "${GREEN}================================================${NC}"
echo "Using kubeconfig: $KUBECONFIG_PATH"
echo "Domain: $DOMAIN"
echo ""

# Function to run kubectl with the specified kubeconfig
kctl() {
    kubectl --kubeconfig="$KUBECONFIG_PATH" "$@"
}

# 1. Check certificate secrets
echo -e "${GREEN}1️⃣ Checking Certificate Secrets${NC}"
echo "--------------------------------"
echo "Checking for 'default-gateway-cert' in 'default' namespace..."
if kctl get secret default-gateway-cert -n default >/dev/null 2>&1; then
    echo -e "  ${GREEN}✅ Found certificate secret in 'default' namespace.${NC}"
else
    echo -e "  ${RED}❌ Certificate secret NOT FOUND in 'default' namespace.${NC}"
fi

echo ""
echo "Checking for 'default-gateway-cert' in 'kgateway-system' namespace..."
if kctl get secret default-gateway-cert -n kgateway-system >/dev/null 2>&1; then
    echo -e "  ${GREEN}✅ Found certificate secret in 'kgateway-system' namespace.${NC}"
else
    echo -e "  ${RED}❌ Certificate secret NOT FOUND in 'kgateway-system' namespace.${NC}"
fi

# 2. Check Gateway status
echo ""
echo -e "${GREEN}2️⃣ Checking Gateway Status${NC}"
echo "---------------------------"
kctl get gateway default-gateway -n default -o yaml

echo ""
echo "Gateway conditions:"
kctl get gateway default-gateway -n default -o jsonpath='{.status.conditions}' | jq '.' || echo -e "${RED}No conditions found${NC}"

# 3. Check Kgateway pods
echo ""
echo -e "${GREEN}3️⃣ Checking Kgateway Pods${NC}"
echo "--------------------------"
kctl get pods -n kgateway-system -l app.kubernetes.io/name=kgateway

echo ""
echo "Kgateway pod logs (last 50 lines):"
POD_NAME=$(kctl get pods -n kgateway-system -l app.kubernetes.io/name=kgateway -o jsonpath='{.items[0].metadata.name}')
if [ -n "$POD_NAME" ]; then
    kctl logs -n kgateway-system "$POD_NAME" --tail=50 | grep -i "tls\|cert\|ssl\|error" || echo "No TLS/certificate related logs found"
else
    echo -e "${RED}❌ No Kgateway pods found${NC}"
fi

# 4. Check HTTPRoutes
echo ""
echo -e "${GREEN}4️⃣ Checking HTTPRoutes${NC}"
echo "-----------------------"
kctl get httproute -A -o wide

# 5. Check Gateway load balancer IP
echo ""
echo -e "${GREEN}5️⃣ Checking Gateway Load Balancer${NC}"
echo "----------------------------------"
GATEWAY_IP=$(kctl get gateway default-gateway -n default -o jsonpath='{.status.addresses[0].value}' 2>/dev/null || echo "")
if [ -n "$GATEWAY_IP" ]; then
    echo "Gateway IP: $GATEWAY_IP"
    
    # Test SSL connection directly to the IP
    echo ""
    echo "Testing SSL connection to Gateway IP:"
    if command -v timeout &> /dev/null; then
        timeout 10 openssl s_client -connect "$GATEWAY_IP:443" -servername "$DOMAIN" -verify_return_error < /dev/null 2>&1 | head -20 || echo -e "${RED}❌ SSL connection failed${NC}"
    else
        openssl s_client -connect "$GATEWAY_IP:443" -servername "$DOMAIN" -verify_return_error < /dev/null 2>&1 | head -20 || echo -e "${RED}❌ SSL connection failed${NC}"
    fi
else
    echo -e "${RED}❌ No Gateway IP found${NC}"
fi

# 6. Check DNS resolution
echo ""
echo -e "${GREEN}6️⃣ Checking DNS Resolution${NC}"
echo "---------------------------"
echo "DNS resolution for $DOMAIN:"
dig +short "$DOMAIN" || echo -e "${RED}❌ DNS resolution failed${NC}"

echo ""
echo "DNS resolution for *.${DOMAIN}:"
dig +short "test.${DOMAIN}" || echo -e "${RED}❌ Wildcard DNS resolution failed${NC}"

# 7. Test HTTPS endpoints
echo ""
echo -e "${GREEN}7️⃣ Testing HTTPS Endpoints (dynamically discovered from HTTPRoutes)${NC}"
echo "-----------------------------------------------------------------"
ENDPOINTS=($(kctl get httproute -A -o jsonpath='{.items[*].spec.hostnames[*]}' 2>/dev/null))

if [ ${#ENDPOINTS[@]} -eq 0 ]; then
    echo "No HTTPRoute endpoints found to test."
else
    for endpoint in "${ENDPOINTS[@]}"; do
        echo "Testing $endpoint:"
        HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -k --connect-timeout 5 "https://$endpoint")
        if [ "$HTTP_STATUS" -eq "000" ]; then
            echo -e "  ${RED}❌ Connection failed (status: $HTTP_STATUS)${NC}"
        elif [ "$HTTP_STATUS" -ge "200" ] && [ "$HTTP_STATUS" -lt "400" ]; then
            echo -e "  ${GREEN}✅ Connection successful (status: $HTTP_STATUS)${NC}"
        else
            echo -e "  ${YELLOW}⚠️  Connection warning (status: $HTTP_STATUS)${NC}"
        fi
        echo ""
    done
fi

# 8. Check Kgateway configuration
echo ""
echo -e "${GREEN}8️⃣ Checking Kgateway Configuration${NC}"
echo "-----------------------------------"
echo "Kgateway Helm values:"
helm --kubeconfig="$KUBECONFIG_PATH" get values kgateway -n kgateway-system || echo -e "${RED}❌ Could not get Helm values${NC}"

# 9. Check namespace labels for discovery
echo ""
echo -e "${GREEN}9️⃣ Checking Namespace Labels${NC}"
echo "-----------------------------"
echo "Default namespace labels:"
kctl get namespace default -o yaml | grep -A10 labels || echo "No labels found"

echo ""
echo "Kgateway-system namespace labels:"
kctl get namespace kgateway-system -o yaml | grep -A10 labels || echo "No labels found"

# 10. Summary and recommendations
echo ""
echo -e "${GREEN}🔧 Troubleshooting Summary${NC}"
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
echo -e "${GREEN}✅ Diagnostic complete!${NC}"
