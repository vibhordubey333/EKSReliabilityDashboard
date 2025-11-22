#!/bin/bash

##############################################################################
# EKS Cluster Validation Script
# Purpose: Comprehensive validation of cluster health and configuration
# Author: SRE Team
# Usage: ./scripts/validate-cluster.sh
##############################################################################

set -e
set -o pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CLUSTER_NAME="eks-reliability-demo"
REGION="us-east-1"

# Counter for pass/fail
PASSED=0
FAILED=0

check_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASSED++))
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAILED++))
}

check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

##############################################################################
# Cluster Connectivity
##############################################################################

section "1. Cluster Connectivity"

if kubectl cluster-info &> /dev/null; then
    check_pass "kubectl can connect to cluster"
    CLUSTER_ENDPOINT=$(kubectl cluster-info | grep "Kubernetes control plane" | awk '{print $NF}')
    echo "   Endpoint: $CLUSTER_ENDPOINT"
else
    check_fail "kubectl cannot connect to cluster"
    exit 1
fi

# Cluster version
K8S_VERSION=$(kubectl version --short 2>/dev/null | grep "Server Version" || kubectl version -o json 2>/dev/null | jq -r '.serverVersion.gitVersion')
check_pass "Kubernetes version: $K8S_VERSION"

##############################################################################
# Node Health
##############################################################################

section "2. Node Health"

NODES=$(kubectl get nodes --no-headers 2>/dev/null)
NODE_COUNT=$(echo "$NODES" | wc -l | tr -d ' ')
READY_NODES=$(echo "$NODES" | grep -c "Ready" || echo "0")

if [ "$READY_NODES" -eq "$NODE_COUNT" ] && [ "$READY_NODES" -gt 0 ]; then
    check_pass "All nodes are Ready ($READY_NODES/$NODE_COUNT)"
else
    check_fail "Some nodes are not Ready ($READY_NODES/$NODE_COUNT)"
fi

echo ""
echo "Node details:"
kubectl get nodes -o wide

##############################################################################
# System Pods
##############################################################################

section "3. System Pods (kube-system)"

SYSTEM_PODS=$(kubectl get pods -n kube-system --no-headers 2>/dev/null)
TOTAL_SYSTEM_PODS=$(echo "$SYSTEM_PODS" | wc -l | tr -d ' ')
RUNNING_SYSTEM_PODS=$(echo "$SYSTEM_PODS" | grep -c "Running" || echo "0")

if [ "$RUNNING_SYSTEM_PODS" -eq "$TOTAL_SYSTEM_PODS" ]; then
    check_pass "All system pods are Running ($RUNNING_SYSTEM_PODS/$TOTAL_SYSTEM_PODS)"
else
    check_warn "Some system pods are not Running ($RUNNING_SYSTEM_PODS/$TOTAL_SYSTEM_PODS)"
fi

# Check critical components
for component in coredns kube-proxy aws-node; do
    if kubectl get pods -n kube-system -l k8s-app=$component 2>/dev/null | grep -q "Running"; then
        check_pass "$component is running"
    else
        check_fail "$component is not running properly"
    fi
done

##############################################################################
# Namespaces
##############################################################################

section "4. Namespaces"

for ns in dev qa prod; do
    if kubectl get namespace "$ns" &> /dev/null; then
        check_pass "Namespace '$ns' exists"
        
        # Check labels
        LABELS=$(kubectl get namespace "$ns" -o jsonpath='{.metadata.labels}')
        echo "   Labels: $LABELS"
        
        # Check resource quota
        if kubectl get resourcequota -n "$ns" &> /dev/null; then
            QUOTA=$(kubectl get resourcequota -n "$ns" --no-headers 2>/dev/null | wc -l | tr -d ' ')
            if [ "$QUOTA" -gt 0 ]; then
                check_pass "Resource quota configured in '$ns'"
            fi
        fi
    else
        check_fail "Namespace '$ns' does not exist"
    fi
done

##############################################################################
# RBAC
##############################################################################

section "5. RBAC Configuration"

# Check for roles in each namespace
for ns in dev qa prod; do
    ROLES=$(kubectl get roles -n "$ns" --no-headers 2>/dev/null | wc -l | tr -d ' ')
    if [ "$ROLES" -gt 0 ]; then
        check_pass "RBAC roles configured in '$ns' ($ROLES role(s))"
    else
        check_warn "No RBAC roles found in '$ns'"
    fi
done

# Test some basic RBAC permissions
echo ""
echo "Testing RBAC permissions:"

# Dev namespace - should allow create deployments
if kubectl auth can-i create deployments -n dev &> /dev/null; then
    check_pass "Can create deployments in dev"
else
    check_warn "Cannot create deployments in dev (this might be expected)"
fi

##############################################################################
# Sample Deployments
##############################################################################

section "6. Sample Deployments"

for ns in dev qa prod; do
    DEPLOYMENTS=$(kubectl get deployments -n "$ns" --no-headers 2>/dev/null | wc -l | tr -d ' ')
    if [ "$DEPLOYMENTS" -gt 0 ]; then
        check_pass "Deployments exist in '$ns'"
        
        # Check if deployment is ready
        READY=$(kubectl get deployments -n "$ns" -o jsonpath='{.items[0].status.conditions[?(@.type=="Available")].status}' 2>/dev/null)
        if [ "$READY" = "True" ]; then
            check_pass "Deployment is Available in '$ns'"
        else
            check_warn "Deployment is not yet Available in '$ns'"
        fi
        
        # Show pod status
        POD_COUNT=$(kubectl get pods -n "$ns" --no-headers 2>/dev/null | wc -l | tr -d ' ')
        RUNNING_PODS=$(kubectl get pods -n "$ns" --no-headers 2>/dev/null | grep -c "Running" || echo "0")
        echo "   Pods: $RUNNING_PODS/$POD_COUNT Running"
    else
        check_warn "No deployments in '$ns'"
    fi
done

##############################################################################
# AWS EKS Status
##############################################################################

section "7. AWS EKS Status"

CLUSTER_STATUS=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" --query 'cluster.status' --output text 2>/dev/null || echo "UNKNOWN")

if [ "$CLUSTER_STATUS" = "ACTIVE" ]; then
    check_pass "EKS cluster status: $CLUSTER_STATUS"
else
    check_warn "EKS cluster status: $CLUSTER_STATUS"
fi

# Get cluster endpoint and version from AWS
CLUSTER_VERSION=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" --query 'cluster.version' --output text 2>/dev/null || echo "unknown")
echo "   Cluster version: $CLUSTER_VERSION"

CLUSTER_ENDPOINT=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" --query 'cluster.endpoint' --output text 2>/dev/null || echo "unknown")
echo "   Endpoint: $CLUSTER_ENDPOINT"

##############################################################################
# Summary
##############################################################################

section "Validation Summary"

TOTAL=$((PASSED + FAILED))
PASS_RATE=$((PASSED * 100 / TOTAL))

echo ""
echo -e "${GREEN}Passed:${NC} $PASSED"
echo -e "${RED}Failed:${NC} $FAILED"
echo -e "Pass Rate: $PASS_RATE%"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All critical checks passed!${NC}"
    echo ""
    echo "Your cluster is ready for use!"
    exit 0
else
    echo -e "${RED}✗ Some checks failed. Please review the output above.${NC}"
    exit 1
fi
