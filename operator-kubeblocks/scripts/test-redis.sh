#!/bin/bash

# Test Redis deployment via KubeBlocks
# Creates a Redis cluster for testing

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
KUBECONFIG_PATH="${KUBECONFIG_PATH:-../../../kubeconfig}"
MANIFEST_PATH="../manifests/test-redis.yaml"
CLUSTER_NAME="redis-test"
NAMESPACE="kb-demos"

echo -e "${GREEN}🔴 Testing Redis deployment via KubeBlocks...${NC}"

# Check prerequisites
if [ ! -f "$KUBECONFIG_PATH" ]; then
    echo -e "${RED}❌ Kubeconfig not found at $KUBECONFIG_PATH${NC}"
    exit 1
fi

if [ ! -f "$MANIFEST_PATH" ]; then
    echo -e "${RED}❌ Manifest not found at $MANIFEST_PATH${NC}"
    exit 1
fi

# Create namespace if it doesn't exist
echo -e "${YELLOW}📦 Creating namespace $NAMESPACE...${NC}"
kubectl --kubeconfig="$KUBECONFIG_PATH" create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl --kubeconfig="$KUBECONFIG_PATH" apply -f -

# Deploy Redis cluster
echo -e "${YELLOW}🚀 Deploying Redis cluster...${NC}"
kubectl --kubeconfig="$KUBECONFIG_PATH" apply -f "$MANIFEST_PATH"

# Wait for cluster to be ready
echo -e "${YELLOW}⏳ Waiting for Redis cluster to be ready...${NC}"
kubectl --kubeconfig="$KUBECONFIG_PATH" wait --for=condition=ready cluster/$CLUSTER_NAME -n $NAMESPACE --timeout=300s

# Show cluster status
echo -e "${GREEN}✅ Redis cluster deployed successfully!${NC}"
echo ""
echo -e "${YELLOW}📋 Cluster Information:${NC}"
kubectl --kubeconfig="$KUBECONFIG_PATH" get cluster $CLUSTER_NAME -n $NAMESPACE
echo ""
echo -e "${YELLOW}📋 Pods:${NC}"
kubectl --kubeconfig="$KUBECONFIG_PATH" get pods -n $NAMESPACE -l app.kubernetes.io/instance=$CLUSTER_NAME
echo ""
echo -e "${YELLOW}📋 Services:${NC}"
kubectl --kubeconfig="$KUBECONFIG_PATH" get svc -n $NAMESPACE -l app.kubernetes.io/instance=$CLUSTER_NAME

echo ""
echo -e "${GREEN}🎉 Redis test completed successfully!${NC}"
echo ""
echo -e "${YELLOW}💡 Useful commands:${NC}"
echo -e "${GREEN}  View logs:${NC} kubectl --kubeconfig=$KUBECONFIG_PATH logs -n $NAMESPACE -l app.kubernetes.io/instance=$CLUSTER_NAME"
echo -e "${GREEN}  Connect:${NC} kubectl --kubeconfig=$KUBECONFIG_PATH port-forward -n $NAMESPACE svc/$CLUSTER_NAME-redis 6379:6379"
echo -e "${GREEN}  Redis CLI:${NC} kubectl --kubeconfig=$KUBECONFIG_PATH exec -it -n $NAMESPACE $CLUSTER_NAME-redis-0 -- redis-cli"
echo -e "${GREEN}  Delete:${NC} kubectl --kubeconfig=$KUBECONFIG_PATH delete cluster $CLUSTER_NAME -n $NAMESPACE"