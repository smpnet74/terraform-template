#!/bin/bash

set -e

KUBECONFIG_PATH=$1
NAMESPACE=$2

if [ -z "$KUBECONFIG_PATH" ] || [ -z "$NAMESPACE" ]; then
  echo "Usage: $0 <kubeconfig-path> <namespace>"
  exit 1
fi

echo "🚀 Starting KubeBlocks operator cleanup for ZenML in namespace '$NAMESPACE'..."

# Let KubeBlocks operator handle proper cleanup
echo "📋 Operator-managed cleanup"

# Wait for operator to process the deletion
echo "  Waiting for KubeBlocks operator to complete cleanup..."
operator_cleanup_success=false
for i in {1..12}; do
  if ! kubectl --kubeconfig="$KUBECONFIG_PATH" get cluster zenml-postgres -n "$NAMESPACE" >/dev/null 2>&1; then
    echo "  ✅ Operator cleanup completed successfully"
    operator_cleanup_success=true
    break
  fi
  echo "  ⏳ Waiting for operator cleanup... ($i/12)"
  sleep 10
done

# Verify cleanup completion
if [ "$operator_cleanup_success" = true ]; then
  echo "🎉 KubeBlocks operator successfully cleaned up all resources"
else
  echo "⚠️  KubeBlocks operator cleanup timed out after 2 minutes"
  echo "   This may indicate the operator needs attention"
fi

echo "🏁 ZenML cleanup completed"
