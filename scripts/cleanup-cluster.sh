#!/bin/bash

##############################################################################
# EKS Cluster Cleanup Script
# Purpose: Safely delete EKS cluster and all associated resources
# Author: SRE Team
# Usage: ./scripts/cleanup-cluster.sh
##############################################################################

set -e
set -o pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CLUSTER_NAME="eks-reliability-demo"
REGION="us-east-1"

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

##############################################################################
# Confirm deletion
##############################################################################

echo ""
log_warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_warning "  CLUSTER DELETION WARNING"
log_warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
log_warning "This script will DELETE the following:"
echo "  • EKS Cluster: $CLUSTER_NAME"
echo "  • Region: $REGION"
echo "  • All worker nodes"
echo "  • All workloads and data"
echo "  • VPC and networking resources"
echo "  • ECR repository: sre-demo-service (including all images)"
echo ""
log_warning "This action CANNOT be undone!"
echo ""

read -p "Are you sure you want to delete the cluster? (type 'yes' to confirm): " -r
echo ""

if [[ ! $REPLY =~ ^yes$ ]]; then
    log_info "Deletion cancelled"
    exit 0
fi

##############################################################################
# Check if cluster exists
##############################################################################

log_info "Checking if cluster exists..."

if ! eksctl get cluster --name "$CLUSTER_NAME" --region "$REGION" &> /dev/null; then
    log_warning "Cluster '$CLUSTER_NAME' does not exist in region '$REGION'"
    exit 0
fi

log_success "Found cluster '$CLUSTER_NAME'"

##############################################################################
# Delete LoadBalancers and PVCs first (to avoid orphaned AWS resources)
##############################################################################

log_info "Cleaning up LoadBalancers and PersistentVolumeClaims..."

# Delete services of type LoadBalancer in all namespaces
for ns in dev qa prod; do
    if kubectl get svc -n "$ns" 2>/dev/null | grep -q LoadBalancer; then
        log_info "Deleting LoadBalancer services in namespace '$ns'..."
        kubectl delete svc --all -n "$ns" --grace-period=0 --force 2>/dev/null || true
    fi
done

# Delete PVCs
for ns in dev qa prod; do
    PVC_COUNT=$(kubectl get pvc -n "$ns" --no-headers 2>/dev/null | wc -l | tr -d ' ')
    if [ "$PVC_COUNT" -gt 0 ]; then
        log_info "Deleting PersistentVolumeClaims in namespace '$ns'..."
        kubectl delete pvc --all -n "$ns" --grace-period=0 --force 2>/dev/null || true
    fi
done

log_info "Waiting 30 seconds for resources to clean up..."
sleep 30

##############################################################################
# Delete cluster
##############################################################################

log_info "Deleting EKS cluster '$CLUSTER_NAME'..."
log_warning "This will take approximately 10-15 minutes..."

if eksctl delete cluster --name "$CLUSTER_NAME" --region "$REGION" --wait; then
    log_success "Cluster deleted successfully!"
else
    log_error "Failed to delete cluster"
    log_info "You may need to manually clean up resources in AWS Console"
    exit 1
fi

##############################################################################
# Delete ECR repository
##############################################################################

log_info "Cleaning up ECR repository..."

ECR_REPO_NAME="sre-demo-service"

# Check if ECR repository exists
if aws ecr describe-repositories --repository-names "$ECR_REPO_NAME" --region "$REGION" &> /dev/null; then
    log_info "Deleting ECR repository '$ECR_REPO_NAME'..."
    
    # Delete all images first (required before deleting repository)
    IMAGE_IDS=$(aws ecr list-images --repository-name "$ECR_REPO_NAME" --region "$REGION" --query 'imageIds[*]' --output json)
    
    if [ "$IMAGE_IDS" != "[]" ]; then
        log_info "Deleting all images in repository..."
        aws ecr batch-delete-image \
            --repository-name "$ECR_REPO_NAME" \
            --region "$REGION" \
            --image-ids "$IMAGE_IDS" &> /dev/null || true
    fi
    
    # Delete the repository
    if aws ecr delete-repository --repository-name "$ECR_REPO_NAME" --region "$REGION" --force &> /dev/null; then
        log_success "ECR repository deleted successfully"
    else
        log_warning "Failed to delete ECR repository. You may need to delete it manually."
    fi
else
    log_info "ECR repository '$ECR_REPO_NAME' does not exist, skipping..."
fi


##############################################################################
# Verify deletion
##############################################################################

log_info "Verifying deletion..."

if eksctl get cluster --name "$CLUSTER_NAME" --region "$REGION" &> /dev/null; then
    log_warning "Cluster still exists. Check AWS Console for more details."
else
    log_success "Cluster deletion verified"
fi

##############################################################################
# Cleanup kubeconfig
##############################################################################

log_info "Cleaning up kubeconfig..."

CONTEXT_NAME="$(kubectl config get-contexts -o name | grep "$CLUSTER_NAME" || echo "")"
if [ -n "$CONTEXT_NAME" ]; then
    kubectl config delete-context "$CONTEXT_NAME" 2>/dev/null || true
    log_success "Removed context from kubeconfig"
fi

##############################################################################
# Final message
##############################################################################

echo ""
log_success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_success "  Cleanup Complete!"
log_success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
log_info "Cluster '$CLUSTER_NAME' has been deleted."
echo ""
log_info "Recommended: Check AWS Console to ensure no resources are orphaned:"
log_info "  • EC2 Dashboard → Load Balancers"
log_info "  • EC2 Dashboard → Volumes"
log_info "  • VPC Dashboard"
log_info "  • CloudFormation → Stacks"
log_info "  • ECR → Repositories"
echo ""
log_success "Thank you for using the EKS Reliability Demo!"
echo ""
