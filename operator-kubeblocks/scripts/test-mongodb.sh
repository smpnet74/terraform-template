#!/bin/bash

# Test MongoDB deployment via KubeBlocks
# Creates a MongoDB cluster for testing

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration

MANIFEST_PATH="../manifests/test-mongodb.yaml"
CLUSTER_NAME="mongodb-test"
NAMESPACE="kubeblocks-test"

echo -e "${GREEN}🍃 Testing MongoDB deployment via KubeBlocks...${NC}"

# Check prerequisites


if [ ! -f "$MANIFEST_PATH" ]; then
    echo -e "${RED}❌ Manifest not found at $MANIFEST_PATH${NC}"
    exit 1
fi

# Create namespace if it doesn't exist
echo -e "${YELLOW}📦 Creating namespace $NAMESPACE...${NC}"
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Deploy MongoDB cluster
echo -e "${YELLOW}🚀 Deploying MongoDB cluster...${NC}"
kubectl apply -f "$MANIFEST_PATH"

# Wait for cluster to be ready
echo -e "${YELLOW}⏳ Waiting for MongoDB cluster to be ready...${NC}"
kubectl wait --for=condition=ready cluster/$CLUSTER_NAME -n $NAMESPACE --timeout=300s

# Show cluster status
echo -e "${GREEN}✅ MongoDB cluster deployed successfully!${NC}"
echo ""
echo -e "${YELLOW}📋 Cluster Information:${NC}"
kubectl get cluster $CLUSTER_NAME -n $NAMESPACE
echo ""
echo -e "${YELLOW}📋 Pods:${NC}"
kubectl get pods -n $NAMESPACE -l app.kubernetes.io/instance=$CLUSTER_NAME
echo ""
echo -e "${YELLOW}📋 Services:${NC}"
kubectl get svc -n $NAMESPACE -l app.kubernetes.io/instance=$CLUSTER_NAME

echo ""
echo -e "${GREEN}🎉 MongoDB test completed successfully!${NC}"
echo ""
echo -e "${YELLOW}💡 Useful commands:${NC}"
echo -e "${GREEN}  View logs:${NC} kubectl  logs -n $NAMESPACE -l app.kubernetes.io/instance=$CLUSTER_NAME"
echo -e "${GREEN}  Connect:${NC} kubectl  port-forward -n $NAMESPACE svc/$CLUSTER_NAME-mongodb 27017:27017"
echo -e "${GREEN}  Mongo shell:${NC} kubectl  exec -it -n $NAMESPACE $CLUSTER_NAME-mongodb-0 -- mongosh"
echo -e "${GREEN}  Delete:${NC} kubectl  delete cluster $CLUSTER_NAME -n $NAMESPACE"