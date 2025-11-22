#!/bin/bash

##############################################################################
# EKS Cluster Setup Script
# Purpose: Orchestrate the complete cluster creation and configuration
# Author: SRE Team
# Usage: ./scripts/setup-cluster.sh
##############################################################################

set -e  # Exit on error
set -o pipefail  # Exit on pipe failure

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
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
total_steps=8

step() {
    log_info "Step $STEP/$total_steps: $1"
    ((STEP++))
}

##############################################################################
# Ensure we're in the project root directory
##############################################################################

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Change to project root
cd "$PROJECT_ROOT" || {
    log_error "Failed to change to project root: $PROJECT_ROOT"
    exit 1
}

log_info "Running from project root: $PROJECT_ROOT"

##############################################################################
# Pre-flight checks
##############################################################################

step "Running pre-flight checks..."

# Check if eksctl is installed
if ! command -v eksctl &> /dev/null; then
    log_error "eksctl is not installed. Please install it first:"
    echo "  macOS: brew install eksctl"
    echo "  Linux: https://github.com/weaveworks/eksctl"
    exit 1
fi
log_success "eksctl is installed ($(eksctl version))"

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    log_error "kubectl is not installed. Please install it first:"
    echo "  macOS: brew install kubectl"
    echo "  Linux: https://kubernetes.io/docs/tasks/tools/"
    exit 1
fi
log_success "kubectl is installed ($(kubectl version --client --short 2>/dev/null || kubectl version --client))"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    log_error "AWS CLI is not installed. Please install it first:"
    echo "  https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    exit 1
fi
log_success "AWS CLI is installed ($(aws --version))"

# Check AWS credentials
step "Validating AWS credentials..."
if ! aws sts get-caller-identity &> /dev/null; then
    log_error "AWS credentials are not configured or invalid."
    echo "  Configure with: aws configure"
    exit 1
fi

AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
AWS_USER=$(aws sts get-caller-identity --query Arn --output text)
log_success "AWS credentials valid"
log_info "  Account: $AWS_ACCOUNT"
log_info "  User: $AWS_USER"

##############################################################################
# Create EKS Cluster
##############################################################################

CLUSTER_NAME="eks-reliability-demo"
REGION="us-east-1"
CONFIG_FILE="cluster-config.yaml"

step "Creating EKS cluster..."
log_warning "This will take approximately 15-20 minutes"
log_info "Cluster name: $CLUSTER_NAME"
log_info "Region: $REGION"
log_info "Config file: $CONFIG_FILE"

if eksctl get cluster --name "$CLUSTER_NAME" --region "$REGION" &> /dev/null; then
    log_warning "Cluster '$CLUSTER_NAME' already exists. Skipping creation."
else
    if eksctl create cluster -f "$CONFIG_FILE"; then
        log_success "Cluster created successfully!"
    else
        log_error "Failed to create cluster"
        exit 1
    fi
fi

##############################################################################
# Update kubeconfig
##############################################################################

step "Updating kubeconfig..."
if aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION"; then
    log_success "kubeconfig updated"
    log_info "Current context: $(kubectl config current-context)"
else
    log_error "Failed to update kubeconfig"
    exit 1
fi

##############################################################################
# Wait for cluster to be fully ready
##############################################################################

step "Waiting for cluster to be ready..."
log_info "Checking node status..."

MAX_RETRIES=30
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if kubectl get nodes &> /dev/null; then
        READY_NODES=$(kubectl get nodes --no-headers 2>/dev/null | grep -c "Ready" || echo "0")
        TOTAL_NODES=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')
        
        if [ "$READY_NODES" -eq "$TOTAL_NODES" ] && [ "$READY_NODES" -gt 0 ]; then
            log_success "All $READY_NODES nodes are ready!"
            break
        else
            log_info "Nodes ready: $READY_NODES/$TOTAL_NODES (waiting...)"
        fi
    fi
    
    ((RETRY_COUNT++))
    sleep 10
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    log_error "Cluster nodes did not become ready in time"
    exit 1
fi

##############################################################################
# Create namespaces
##############################################################################

step "Creating namespaces..."
for namespace in dev qa prod; do
    if kubectl apply -f "k8s/namespaces/${namespace}-namespace.yaml"; then
        log_success "Namespace '$namespace' created"
    else
        log_error "Failed to create namespace '$namespace'"
        exit 1
    fi
done

##############################################################################
# Apply RBAC policies
##############################################################################

step "Applying RBAC policies..."
for rbac_file in k8s/rbac/*.yaml; do
    if kubectl apply -f "$rbac_file"; then
        log_success "Applied $(basename $rbac_file)"
    else
        log_error "Failed to apply $(basename $rbac_file)"
        exit 1
    fi
done

##############################################################################
# Deploy sample application
##############################################################################

step "Deploying sample nginx application to all namespaces..."
for namespace in dev qa prod; do
    if kubectl apply -f k8s/samples/nginx-deployment.yaml -n "$namespace"; then
        log_success "Deployed to namespace '$namespace'"
    else
        log_error "Failed to deploy to namespace '$namespace'"
        exit 1
    fi
done

##############################################################################
# Final validation
##############################################################################

log_info ""
log_info "=========================================="
log_info "   Cluster Setup Complete!"
log_info "=========================================="
log_info ""
log_info "Cluster Name: $CLUSTER_NAME"
log_info "Region: $REGION"
log_info ""
log_info "Quick commands to get started:"
log_info "  kubectl get nodes"
log_info "  kubectl get namespaces"
log_info "  kubectl get pods -A"
log_info "  kubectl get deployments -n dev"
log_info ""
log_info "Run validation script:"
log_info "  ./scripts/validate-cluster.sh"
log_info ""
log_warning "IMPORTANT: Remember to delete the cluster when done to avoid charges!"
log_warning "  ./scripts/cleanup-cluster.sh"
log_info ""
