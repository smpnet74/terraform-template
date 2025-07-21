#!/bin/bash

# ZenML KubeBlocks Cleanup Script
# This script forcefully cleans up stuck KubeBlocks resources that prevent namespace deletion
# Run this if 'terraform destroy' fails due to KubeBlocks finalizers

set -e

ZENML_NAMESPACE="${1:-zenml-system}"
KUBECONFIG_PATH="${2:-./kubeconfig}"

echo "🧹 ZenML KubeBlocks Cleanup Script"
echo "Namespace: $ZENML_NAMESPACE"
echo "Kubeconfig: $KUBECONFIG_PATH"
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed or not in PATH"
    exit 1
fi

echo "🔍 Brute force cleaning KubeBlocks resources in namespace $ZENML_NAMESPACE..."
echo "⚠️  This script will attempt cleanup regardless of namespace state (including Terminating)"

# First, try to remove namespace finalizers if it's stuck in Terminating
echo "🛠️  Step 0: Removing namespace finalizers (if stuck in Terminating)..."
kubectl --kubeconfig="$KUBECONFIG_PATH" patch namespace "$ZENML_NAMESPACE" \
    --type='merge' -p='{"metadata":{"finalizers":null}}' 2>/dev/null || true

# Function to force delete resources with finalizers
cleanup_resource_type() {
    local resource_type=$1
    echo "  Cleaning up $resource_type..."
    
    # Get all resources of this type
    local resources=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get "$resource_type" -n "$ZENML_NAMESPACE" -o name 2>/dev/null || true)
    
    if [ -n "$resources" ]; then
        echo "    Found stuck $resource_type resources, removing finalizers..."
        echo "$resources" | while read -r resource; do
            kubectl --kubeconfig="$KUBECONFIG_PATH" patch "$resource" -n "$ZENML_NAMESPACE" \
                -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
        done
        
        # Force delete remaining resources
        echo "    Force deleting $resource_type resources..."
        kubectl --kubeconfig="$KUBECONFIG_PATH" delete "$resource_type" -n "$ZENML_NAMESPACE" \
            --all --timeout=30s --ignore-not-found=true || true
    fi
}

# Clean up KubeBlocks resources in order of dependency
echo "🗑️ Cleaning up KubeBlocks managed resources..."

# Clean up backup-related resources first (they have dataprotection.kubeblocks.io/finalizer)
echo "  🗂️ Cleaning up KubeBlocks backup resources..."
cleanup_resource_type "backupschedules"
cleanup_resource_type "backuppolicies"
cleanup_resource_type "backups"
cleanup_resource_type "restores"

# Clean up core KubeBlocks resources (they have component.kubeblocks.io/finalizer)
echo "  🏗️ Cleaning up core KubeBlocks resources..."
cleanup_resource_type "instancesets"
cleanup_resource_type "components"
cleanup_resource_type "clusters"

# Clean up additional KubeBlocks CRDs that might exist
echo "  🔧 Cleaning up additional KubeBlocks resources..."
cleanup_resource_type "componentdefinitions"
cleanup_resource_type "clusterdefinitions"
cleanup_resource_type "backuprepositories"
cleanup_resource_type "actionsets"

# Specific manual cleanup for known stuck resources
echo "🎯 Step 1: Manual cleanup of specific stuck resources..."

# Remove backup policy finalizers (these are the main culprits)
echo "  Removing backup policy finalizers..."
kubectl --kubeconfig="$KUBECONFIG_PATH" patch backuppolicy zenml-postgres-postgresql-backup-policy -n "$ZENML_NAMESPACE" \
    --type='merge' -p='{"metadata":{"finalizers":null}}' 2>/dev/null || true

# Remove backup schedule finalizers
echo "  Removing backup schedule finalizers..."
kubectl --kubeconfig="$KUBECONFIG_PATH" patch backupschedule zenml-postgres-postgresql-backup-schedule -n "$ZENML_NAMESPACE" \
    --type='merge' -p='{"metadata":{"finalizers":null}}' 2>/dev/null || true

# Remove finalizers from all secrets in bulk
echo "  Removing finalizers from all secrets..."
kubectl --kubeconfig="$KUBECONFIG_PATH" get secrets -n "$ZENML_NAMESPACE" -o name 2>/dev/null | \
    xargs -I {} kubectl --kubeconfig="$KUBECONFIG_PATH" patch {} -n "$ZENML_NAMESPACE" \
    --type='merge' -p='{"metadata":{"finalizers":null}}' 2>/dev/null || true

# Remove finalizers from the PostgreSQL service
echo "  Removing finalizers from PostgreSQL service..."
kubectl --kubeconfig="$KUBECONFIG_PATH" patch service zenml-postgres-postgresql-postgresql -n "$ZENML_NAMESPACE" \
    --type='merge' -p='{"metadata":{"finalizers":null}}' 2>/dev/null || true

# Clean up ConfigMaps, Secrets, and Services with KubeBlocks finalizers
echo "🧹 Cleaning up ConfigMaps, Secrets, and Services with KubeBlocks finalizers..."

# Remove finalizers from ConfigMaps with KubeBlocks finalizers
echo "  Cleaning up ConfigMaps..."
kubectl --kubeconfig="$KUBECONFIG_PATH" get configmaps -n "$ZENML_NAMESPACE" -o json 2>/dev/null | \
    jq -r '.items[] | select(.metadata.finalizers != null and (.metadata.finalizers[] | contains("kubeblocks.io/finalizer"))) | .metadata.name' | \
    while read -r cm_name; do
        if [ -n "$cm_name" ]; then
            echo "    Removing finalizers from ConfigMap: $cm_name"
            kubectl --kubeconfig="$KUBECONFIG_PATH" patch configmap "$cm_name" -n "$ZENML_NAMESPACE" \
                -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
        fi
    done

# Remove finalizers from Secrets with KubeBlocks finalizers
echo "  Cleaning up Secrets..."
kubectl --kubeconfig="$KUBECONFIG_PATH" get secrets -n "$ZENML_NAMESPACE" -o json 2>/dev/null | \
    jq -r '.items[] | select(.metadata.finalizers != null and (.metadata.finalizers[] | contains("kubeblocks.io/finalizer"))) | .metadata.name' | \
    while read -r secret_name; do
        if [ -n "$secret_name" ]; then
            echo "    Removing finalizers from Secret: $secret_name"
            kubectl --kubeconfig="$KUBECONFIG_PATH" patch secret "$secret_name" -n "$ZENML_NAMESPACE" \
                -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
        fi
    done

# Remove finalizers from Services with KubeBlocks finalizers
echo "  Cleaning up Services..."
kubectl --kubeconfig="$KUBECONFIG_PATH" get services -n "$ZENML_NAMESPACE" -o json 2>/dev/null | \
    jq -r '.items[] | select(.metadata.finalizers != null and (.metadata.finalizers[] | contains("kubeblocks.io/finalizer"))) | .metadata.name' | \
    while read -r svc_name; do
        if [ -n "$svc_name" ]; then
            echo "    Removing finalizers from Service: $svc_name"
            kubectl --kubeconfig="$KUBECONFIG_PATH" patch service "$svc_name" -n "$ZENML_NAMESPACE" \
                -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
        fi
    done

# Force delete any remaining resources with finalizers
echo "  Force deleting remaining ConfigMaps, Secrets, and Services..."
kubectl --kubeconfig="$KUBECONFIG_PATH" delete configmaps,secrets,services --all -n "$ZENML_NAMESPACE" \
    --force --grace-period=0 --ignore-not-found=true 2>/dev/null || true

# Nuclear option: Remove finalizers from ALL remaining resources
echo "💣 Step 2: Nuclear cleanup - removing finalizers from ALL remaining resources..."
for resource_type in $(kubectl --kubeconfig="$KUBECONFIG_PATH" api-resources --namespaced=true -o name 2>/dev/null); do
    echo "  Checking $resource_type..."
    kubectl --kubeconfig="$KUBECONFIG_PATH" get "$resource_type" -n "$ZENML_NAMESPACE" -o name 2>/dev/null | \
        xargs -I {} kubectl --kubeconfig="$KUBECONFIG_PATH" patch {} -n "$ZENML_NAMESPACE" \
        --type='merge' -p='{"metadata":{"finalizers":null}}' 2>/dev/null || true
done

# Clean up any remaining KubeBlocks CRDs in the namespace
echo "  Cleaning up any remaining KubeBlocks CRDs..."
kubectl --kubeconfig="$KUBECONFIG_PATH" get all -n "$ZENML_NAMESPACE" 2>/dev/null | grep kubeblocks || true

# Try to delete the namespace if it's stuck
echo "🏗️ Checking namespace status..."
namespace_status=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get namespace "$ZENML_NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")

if [ "$namespace_status" = "Terminating" ]; then
    echo "  Namespace is stuck in Terminating state, attempting force cleanup..."
    
    # Get the namespace JSON and remove finalizers
    kubectl --kubeconfig="$KUBECONFIG_PATH" get namespace "$ZENML_NAMESPACE" -o json | \
        jq '.spec.finalizers = []' | \
        kubectl --kubeconfig="$KUBECONFIG_PATH" replace --raw "/api/v1/namespaces/$ZENML_NAMESPACE/finalize" -f - 2>/dev/null || true
elif [ "$namespace_status" = "Active" ]; then
    echo "  Namespace is active, attempting normal deletion..."
    kubectl --kubeconfig="$KUBECONFIG_PATH" delete namespace "$ZENML_NAMESPACE" --timeout=60s || true
fi

# Final verification
echo "✅ Cleanup completed. Verifying namespace deletion..."
sleep 5

if kubectl --kubeconfig="$KUBECONFIG_PATH" get namespace "$ZENML_NAMESPACE" &> /dev/null; then
    echo "⚠️  Namespace $ZENML_NAMESPACE still exists. You may need to:"
    echo "   1. Ensure KubeBlocks operator is running"
    echo "   2. Run this script again"
    echo "   3. Manually remove remaining finalizers"
    echo ""
    echo "Remaining resources in namespace:"
    kubectl --kubeconfig="$KUBECONFIG_PATH" get all -n "$ZENML_NAMESPACE" 2>/dev/null || true
else
    echo "🎉 Namespace $ZENML_NAMESPACE successfully deleted!"
fi

echo ""
echo "💡 Usage: $0 [namespace] [kubeconfig-path]"
echo "   Default namespace: zenml-system"
echo "   Default kubeconfig: ./kubeconfig"