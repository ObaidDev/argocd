#!/bin/bash
# Install cert-manager via Helm (idempotent - skips if already installed)

set -euo pipefail

NAMESPACE="cert-manager"
RELEASE_NAME="cert-manager"
REPO_NAME="jetstack"
REPO_URL="https://charts.jetstack.io"
CERT_MANAGER_VERSION="v1.17.1"

echo "=== cert-manager Setup ==="

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    echo "ERROR: helm is not installed. Please install helm first."
    exit 1
fi

# Add Jetstack Helm repo if not already added
if ! helm repo list 2>/dev/null | grep -q "$REPO_NAME"; then
    echo "Adding Jetstack Helm repo..."
    helm repo add "$REPO_NAME" "$REPO_URL"
else
    echo "Jetstack Helm repo already added."
fi

helm repo update

# Create namespace if not exists
if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
    echo "Creating namespace $NAMESPACE..."
    kubectl create namespace "$NAMESPACE"
else
    echo "Namespace $NAMESPACE already exists."
fi

# Install or skip cert-manager
if helm list -n "$NAMESPACE" 2>/dev/null | grep -q "$RELEASE_NAME"; then
    echo "cert-manager is already installed. Upgrading..."
    helm upgrade "$RELEASE_NAME" "$REPO_NAME/cert-manager" \
        --namespace "$NAMESPACE" \
        --version "$CERT_MANAGER_VERSION" \
        --set crds.enabled=true
else
    echo "Installing cert-manager..."
    helm install "$RELEASE_NAME" "$REPO_NAME/cert-manager" \
        --namespace "$NAMESPACE" \
        --version "$CERT_MANAGER_VERSION" \
        --set crds.enabled=true
fi

# Wait for cert-manager pods to be ready
echo "Waiting for cert-manager pods to be ready..."
kubectl wait --for=condition=Ready pods --all -n "$NAMESPACE" --timeout=120s

echo ""
echo "=== cert-manager is ready ==="
kubectl get pods -n "$NAMESPACE"

echo ""
echo "Now apply the ClusterIssuer:"
echo "  kubectl apply -f infrastructure/cluster-issuer.yaml"
