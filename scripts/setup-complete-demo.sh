#!/bin/bash

##############################################################################
# Complete SRE Demo Setup Script
# Purpose: Orchestrate full deployment (cluster, observability, application)
# Author: SRE Team
# Usage: ./scripts/setup-complete-demo.sh
##############################################################################

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

# Step counter
STEP=1
TOTAL_STEPS=5

step() {
    echo ""
    log_info "====================="
    log_info "Step $STEP/$TOTAL_STEPS: $1"
    log_info "====================="
    echo ""
    ((STEP++))
}

##############################################################################
# Ensure we're in project root
##############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT" || {
    log_error "Failed to change to project root: $PROJECT_ROOT"
    exit 1
}

##############################################################################
# Introduction
##############################################################################

echo ""
echo "========================================="
echo "   Complete EKS SRE Demo Setup"
echo "========================================="
echo ""
log_warning "This script will:"
echo "  1. Create EKS cluster (15-20 minutes)"
echo "  2. Install Prometheus & Grafana"
echo "  3. Install Elasticsearch, Fluent Bit & Kibana"
echo "  4. Build and push Docker image"
echo "  5. Deploy SRE demo service to dev/qa/prod"
echo ""
log_warning "Total estimated time: 30-40 minutes"
log_warning "Estimated cost: ~\$133/month while running"
echo ""

read -p "Continue? (yes/no): " -r
echo ""
if [[ ! $REPLY =~ ^yes$ ]]; then
    log_info "Setup cancelled"
    exit 0
fi

##############################################################################
# Step 1: Create EKS Cluster
##############################################################################

step "Creating EKS cluster"

if ./scripts/setup-cluster.sh; then
    log_success "Cluster created successfully"
else
    log_error "Cluster creation failed"
    exit 1
fi

##############################################################################
# Step 2: Install Monitoring Stack
##############################################################################

step "Installing monitoring stack (Prometheus & Grafana)"

if ./scripts/install-monitoring.sh; then
    log_success "Monitoring stack installed"
else
    log_error "Monitoring installation failed"
    log_warning "Continuing anyway - you can install later with: ./scripts/install-monitoring.sh"
fi

##############################################################################
# Step 3: Install Logging Stack
##############################################################################

step "Installing logging stack (Elasticsearch, Fluent Bit, Kibana)"

if ./scripts/install-logging.sh; then
    log_success "Logging stack installed"
else
    log_error "Logging installation failed"
    log_warning "Continuing anyway - you can install later with: ./scripts/install-logging.sh"
fi

##############################################################################
# Step 4: Build and Push Docker Image
##############################################################################

step "Building and pushing Docker image"

# Check if Docker is running
if ! docker info &> /dev/null; then
    log_error "Docker daemon is not running"
    log_info "Please start Docker and run: ./scripts/build-and-push.sh"
    log_warning "Skipping image build - using existing image if available"
else
    if ./scripts/build-and-push.sh; then
        log_success "Docker image built and pushed"
    else
        log_error "Image build failed"
        log_warning "Continuing anyway - deployment may fail if image doesn't exist"
    fi
fi

##############################################################################
# Step 5: Deploy SRE Demo Service
##############################################################################

step "Deploying SRE demo service to all environments"

# Deploy to dev
log_info "Deploying to dev namespace..."
if kubectl apply -f k8s/deployments/dev/; then
    log_success "Deployed to dev"
else
    log_error "Failed to deploy to dev"
    exit 1
fi

# Deploy to qa
log_info "Deploying to qa namespace..."
if kubectl apply -f k8s/deployments/qa/; then
    log_success "Deployed to qa"
else
    log_error "Failed to deploy to qa"
    exit 1
fi

# Deploy to prod
log_info "Deploying to prod namespace..."
if kubectl apply -f k8s/deployments/prod/; then
    log_success "Deployed to prod"
else
    log_error "Failed to deploy to prod"
    exit 1
fi

##############################################################################
# Wait for pods to be ready
##############################################################################

log_info "Waiting for pods to be ready..."
echo ""

for namespace in dev qa prod; do
    log_info "Checking $namespace namespace..."
    kubectl wait --for=condition=ready pod \
        -l app=sre-demo-service \
        -n "$namespace" \
        --timeout=120s || log_warning "$namespace pods not ready yet"
done

##############################################################################
# Final Summary
##############################################################################

echo ""
echo "========================================="
echo "   Setup Complete!"
echo "========================================="
echo ""
log_success "All components deployed successfully"
echo ""
log_info "Quick Status Check:"
kubectl get pods -n dev -l app=sre-demo-service
echo ""
log_info "Access Points:"
echo "  Grafana:       ./scripts/access-grafana.sh"
echo "  Kibana:        ./scripts/access-kibana.sh"
echo "  Dev Service:   kubectl port-forward -n dev svc/sre-demo-service 8080:8080"
echo "  Prometheus:    kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090"
echo ""
log_info "Verify Deployment:"
echo "  kubectl get pods -A"
echo "  kubectl get svc -A"
echo "  kubectl top nodes"
echo ""
log_info "Test Application:"
echo "  kubectl port-forward -n dev svc/sre-demo-service 8080:8080"
echo "  curl http://localhost:8080/health"
echo "  curl http://localhost:8080/metrics"
echo ""
log_warning "IMPORTANT: Delete cluster when done to avoid charges!"
echo "  ./scripts/cleanup-cluster.sh"
echo ""
