#!/bin/bash

# Quick access to Grafana dashboard
# This script port-forwards Grafana and displays login credentials

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo -e "${BLUE}=== Grafana Access ===${NC}"
echo ""

# Check if monitoring namespace exists
if ! kubectl get namespace monitoring &> /dev/null; then
    echo -e "${YELLOW}Monitoring namespace not found.${NC}"
    echo "Run: ./scripts/install-monitoring.sh"
    exit 1
fi

# Get Grafana password
echo -e "${BLUE}Grafana Credentials:${NC}"
echo "  Username: admin"
GRAFANA_PASSWORD=$(kubectl get secret -n monitoring prometheus-grafana -o jsonpath='{.data.admin-password}' 2>/dev/null | base64 -d)
if [ -z "$GRAFANA_PASSWORD" ]; then
    echo "  Password: admin123 (default)"
else
    echo "  Password: $GRAFANA_PASSWORD"
fi
echo ""

echo -e "${GREEN}Starting port-forward to Grafana...${NC}"
echo "  URL: http://localhost:3000"
echo "  Press Ctrl+C to stop"
echo ""

# Port-forward Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
