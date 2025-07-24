#!/bin/bash

# Test Neo4j deployment via KubeBlocks
# Creates a Neo4j graph database cluster for testing

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
KUBECONFIG_PATH="${KUBECONFIG_PATH:-../../../kubeconfig}"
MANIFEST_PATH="../manifests/test-neo4j.yaml"
CLUSTER_NAME="neo4j-test"
NAMESPACE="kb-demos"

echo -e "${GREEN}🔗 Testing Neo4j deployment via KubeBlocks...${NC}"

# Check prerequisites
if [ ! -f "$KUBECONFIG_PATH" ]; then
    echo -e "${RED}❌ Kubeconfig not found at $KUBECONFIG_PATH${NC}"
    exit 1
fi

if [ ! -f "$MANIFEST_PATH" ]; then
    echo -e "${RED}❌ Manifest not found at $MANIFEST_PATH${NC}"
    exit 1
fi

# Check if Neo4j ComponentDefinition is available
echo -e "${YELLOW}🔍 Checking Neo4j ComponentDefinition availability...${NC}"
if ! kubectl --kubeconfig="$KUBECONFIG_PATH" get componentdefinition neo4j-1.0.0 >/dev/null 2>&1; then
    echo -e "${RED}❌ Neo4j ComponentDefinition not found. Make sure the Neo4j addon is installed.${NC}"
    echo -e "${YELLOW}💡 Available ComponentDefinitions:${NC}"
    kubectl --kubeconfig="$KUBECONFIG_PATH" get componentdefinition | grep neo4j || echo "No Neo4j ComponentDefinitions found"
    exit 1
fi

echo -e "${GREEN}✅ Neo4j ComponentDefinition found${NC}"

# Create namespace if it doesn't exist
echo -e "${YELLOW}📦 Creating namespace $NAMESPACE...${NC}"
kubectl --kubeconfig="$KUBECONFIG_PATH" create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl --kubeconfig="$KUBECONFIG_PATH" apply -f -

# Deploy Neo4j cluster
echo -e "${YELLOW}🚀 Deploying Neo4j cluster...${NC}"
kubectl --kubeconfig="$KUBECONFIG_PATH" apply -f "$MANIFEST_PATH"

# Wait for cluster to be ready
echo -e "${YELLOW}⏳ Waiting for Neo4j cluster to be ready (this may take a few minutes)...${NC}"
kubectl --kubeconfig="$KUBECONFIG_PATH" wait --for=condition=ready cluster/$CLUSTER_NAME -n $NAMESPACE --timeout=600s

# Show cluster status
echo -e "${GREEN}✅ Neo4j cluster deployed successfully!${NC}"
echo ""
echo -e "${YELLOW}📋 Cluster Information:${NC}"
kubectl --kubeconfig="$KUBECONFIG_PATH" get cluster $CLUSTER_NAME -n $NAMESPACE
echo ""
echo -e "${YELLOW}📋 Pods:${NC}"
kubectl --kubeconfig="$KUBECONFIG_PATH" get pods -n $NAMESPACE -l app.kubernetes.io/instance=$CLUSTER_NAME
echo ""
echo -e "${YELLOW}📋 Services:${NC}"
kubectl --kubeconfig="$KUBECONFIG_PATH" get svc -n $NAMESPACE -l app.kubernetes.io/instance=$CLUSTER_NAME

# Get connection information
echo ""
echo -e "${GREEN}🎉 Neo4j test completed successfully!${NC}"
echo ""
echo -e "${YELLOW}🔐 Connection Information:${NC}"
echo -e "${GREEN}  Username:${NC} neo4j"
echo -e "${GREEN}  Password:${NC} testpassword123"
echo ""
echo -e "${YELLOW}💡 Useful commands:${NC}"
echo -e "${GREEN}  View logs:${NC} kubectl --kubeconfig=$KUBECONFIG_PATH logs -n $NAMESPACE -l app.kubernetes.io/instance=$CLUSTER_NAME"
echo -e "${GREEN}  Neo4j Browser:${NC} kubectl --kubeconfig=$KUBECONFIG_PATH port-forward -n $NAMESPACE svc/$CLUSTER_NAME-neo4j-http 7474:7474"
echo -e "${GREEN}  Bolt Protocol:${NC} kubectl --kubeconfig=$KUBECONFIG_PATH port-forward -n $NAMESPACE svc/$CLUSTER_NAME-neo4j-http 7687:7687"
echo -e "${GREEN}  Neo4j Shell:${NC} kubectl --kubeconfig=$KUBECONFIG_PATH exec -it -n $NAMESPACE $CLUSTER_NAME-neo4j-0 -- cypher-shell -u neo4j -p testpassword123"
echo -e "${GREEN}  Delete:${NC} kubectl --kubeconfig=$KUBECONFIG_PATH delete cluster $CLUSTER_NAME -n $NAMESPACE"
echo ""
echo -e "${YELLOW}🌐 Access Neo4j Browser:${NC}"
echo -e "  1. Run: kubectl --kubeconfig=$KUBECONFIG_PATH port-forward -n $NAMESPACE svc/$CLUSTER_NAME-neo4j-http 7474:7474"
echo -e "  2. Open: http://localhost:7474"
echo -e "  3. Connect with: bolt://localhost:7687 (neo4j/testpassword123)"