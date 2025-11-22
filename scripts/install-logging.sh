#!/bin/bash

# Install EFK Stack (Elasticsearch, Fluent Bit, Kibana)
# This script deploys centralized logging using Helm

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
log_info "=== Install EFK Stack (Elasticsearch + Fluent Bit + Kibana) ==="
echo ""

# Check prerequisites
log_info "Checking prerequisites..."

if ! command -v kubectl &> /dev/null; then
    log_error "kubectl not found."
    exit 1
fi

if ! command -v helm &> /dev/null; then
    log_error "helm not found."
    exit 1
fi

if ! kubectl cluster-info &> /dev/null; then
    log_error "Cannot connect to Kubernetes cluster."
    log_info "Run: ./scripts/setup-cluster.sh"
    exit 1
fi

log_success "Prerequisites validated"
echo ""

# Create logging namespace
log_info "Creating logging namespace..."
if kubectl get namespace logging &> /dev/null; then
    log_warning "Namespace 'logging' already exists"
else
    kubectl create namespace logging
    log_success "Namespace 'logging' created"
fi
echo ""

# Add Helm repositories
log_info "Adding Helm repositories..."
helm repo add elastic https://helm.elastic.co
helm repo add fluent https://fluent.github.io/helm-charts
helm repo update
log_success "Helm repositories added"
echo ""

# Install Elasticsearch
log_info "Installing Elasticsearch..."
log_warning "This may take 3-5 minutes..."
echo ""

helm upgrade --install elasticsearch elastic/elasticsearch \
  --namespace logging \
  --values "$(dirname "$0")/../k8s/logging/elasticsearch-values.yaml" \
  --wait \
  --timeout 10m

log_success "Elasticsearch installed"
echo ""

# Install Kibana
log_info "Installing Kibana..."
helm upgrade --install kibana elastic/kibana \
  --namespace logging \
  --values "$(dirname "$0")/../k8s/logging/kibana-values.yaml" \
  --wait \
  --timeout 5m

log_success "Kibana installed"
echo ""

# Install Fluent Bit
log_info "Installing Fluent Bit..."
helm upgrade --install fluent-bit fluent/fluent-bit \
  --namespace logging \
  --values "$(dirname "$0")/../k8s/logging/fluent-bit-values.yaml" \
  --wait \
  --timeout 5m

log_success "Fluent Bit installed"
echo ""

# Wait for pods
log_info "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app=elasticsearch-master -n logging --timeout=300s
kubectl wait --for=condition=ready pod -l app=kibana -n logging --timeout=300s

log_success "All pods are ready"
echo ""

# Display status
log_info "Pod status:"
kubectl get pods -n logging
echo ""

# Display access instructions
log_success "=== Installation Complete ==="
echo ""
log_info "Access Kibana:"
echo "  1. Run: ./scripts/access-kibana.sh"
echo "  2. Or manually: kubectl port-forward -n logging svc/kibana-kibana 5601:5601"
echo "  3. Open: http://localhost:5601"
echo ""
log_info "Create Index Pattern:"
echo "  1. Navigate to Stack Management > Index Patterns"
echo "  2. Create pattern: logstash-*"
echo "  3. Time field: @timestamp"
echo ""
log_info "Query Example:"
echo '  kubernetes.namespace_name: "dev"'
echo ""
