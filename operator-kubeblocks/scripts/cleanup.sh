#!/bin/bash

# Cleanup script for KubeBlocks test deployments

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="kb-demos"

echo -e "${YELLOW}🧹 Cleaning up resources in namespace: $NAMESPACE...${NC}"

# Delete all clusters in the namespace
if kubectl get clusters -n $NAMESPACE -o name | grep -q .; then
    echo -e "${YELLOW}🗑️ Deleting all clusters in namespace $NAMESPACE...${NC}"
    kubectl delete clusters --all -n $NAMESPACE
else
    echo -e "${GREEN}✅ No clusters found in namespace $NAMESPACE.${NC}"
fi

# Delete the namespace
echo -e "${YELLOW}🗑️ Deleting namespace $NAMESPACE...${NC}"
kubectl delete namespace $NAMESPACE --ignore-not-found=true

echo -e "${GREEN}🎉 Cleanup complete!${NC}"
