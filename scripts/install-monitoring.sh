#!/bin/bash

# Install kube-prometheus-stack for cluster monitoring
# This script deploys Prometheus and Grafana using Helm

set -e
set -o pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo ""
log_info "=== Install kube-prometheus-stack ==="
echo ""

# Check prerequisites
log_info "Checking prerequisites..."

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    log_error "kubectl not found. Please install kubectl first."
    exit 1
fi

# Check helm
if ! command -v helm &> /dev/null; then
    log_error "helm not found. Please install helm first."
    exit 1
fi

# Check cluster connectivity
if ! kubectl cluster-info &> /dev/null; then
    log_error "Cannot connect to Kubernetes cluster."
    log_info "Please ensure your EKS cluster is running and kubeconfig is set."
    log_info "Run: ./scripts/setup-cluster.sh"
    exit 1
fi

log_success "Prerequisites validated"
echo ""

# Create monitoring namespace
log_info "Creating monitoring namespace..."
if kubectl get namespace monitoring &> /dev/null; then
    log_warning "Namespace 'monitoring' already exists"
else
    kubectl create namespace monitoring
    log_success "Namespace 'monitoring' created"
fi
echo ""

# Add prometheus-community Helm repository
log_info "Adding prometheus-community Helm repository..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
log_success "Helm repository added and updated"
echo ""

# Install kube-prometheus-stack
log_info "Installing kube-prometheus-stack..."
log_warning "This may take 2-3 minutes..."
echo ""

helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values "$(dirname "$0")/../k8s/monitoring/values.yaml" \
  --wait \
  --timeout 10m

log_success "kube-prometheus-stack installed successfully"
echo ""

# Wait for pods to be ready
log_info "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l "app.kubernetes.io/name=grafana" -n monitoring --timeout=300s
kubectl wait --for=condition=ready pod -l "app.kubernetes.io/name=prometheus" -n monitoring --timeout=300s

log_success "All pods are ready"
echo ""

# Display pod status
log_info "Pod status:"
kubectl get pods -n monitoring
echo ""

# Display access instructions
log_success "=== Installation Complete ==="
echo ""
log_info "Access Grafana:"
echo "  1. Run: ./scripts/access-grafana.sh"
echo "  2. Or manually: kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
echo "  3. Open: http://localhost:3000"
echo "  4. Login: admin / admin123"
echo ""
log_info "Access Prometheus:"
echo "  kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090"
echo "  Open: http://localhost:9090"
echo ""
log_info "Get Grafana password:"
echo "  kubectl get secret -n monitoring prometheus-grafana -o jsonpath='{.data.admin-password}' | base64 -d"
echo ""
