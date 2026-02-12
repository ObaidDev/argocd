#!/bin/bash
# Install HAProxy Ingress Controller via Helm (idempotent - skips if already installed)

set -euo pipefail

NAMESPACE="haproxy-controller"
RELEASE_NAME="haproxy-ingress"
REPO_NAME="haproxytech"
REPO_URL="https://haproxytech.github.io/helm-charts"

echo "=== HAProxy Ingress Controller Setup ==="

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    echo "ERROR: helm is not installed. Please install helm first."
    exit 1
fi

# Add HAProxy Helm repo if not already added
if ! helm repo list 2>/dev/null | grep -q "$REPO_NAME"; then
    echo "Adding HAProxy Helm repo..."
    helm repo add "$REPO_NAME" "$REPO_URL"
else
    echo "HAProxy Helm repo already added."
fi

helm repo update

# Create namespace if not exists
if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
    echo "Creating namespace $NAMESPACE..."
    kubectl create namespace "$NAMESPACE"
else
    echo "Namespace $NAMESPACE already exists."
fi

# Install or skip HAProxy Ingress
if helm list -n "$NAMESPACE" 2>/dev/null | grep -q "$RELEASE_NAME"; then
    echo "HAProxy Ingress is already installed. Upgrading..."
    helm upgrade "$RELEASE_NAME" "$REPO_NAME/kubernetes-ingress" \
        --namespace "$NAMESPACE" \
        --set controller.kind=DaemonSet \
        --set controller.ingressClassResource.default=true \
        --set controller.service.type=LoadBalancer
else
    echo "Installing HAProxy Ingress Controller..."
    helm install "$RELEASE_NAME" "$REPO_NAME/kubernetes-ingress" \
        --namespace "$NAMESPACE" \
        --set controller.kind=DaemonSet \
        --set controller.ingressClassResource.default=true \
        --set controller.service.type=LoadBalancer
fi

echo ""
echo "=== HAProxy Ingress Controller is ready ==="
kubectl get pods -n "$NAMESPACE"
