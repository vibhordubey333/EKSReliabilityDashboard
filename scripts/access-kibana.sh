#!/bin/bash

# Quick access to Kibana dashboard

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo -e "${BLUE}=== Kibana Access ===${NC}"
echo ""

# Check if logging namespace exists
if ! kubectl get namespace logging &> /dev/null; then
    echo -e "${YELLOW}Logging namespace not found.${NC}"
    echo "Run: ./scripts/install-logging.sh"
    exit 1
fi

echo -e "${GREEN}Starting port-forward to Kibana...${NC}"
echo "  URL: http://localhost:5601"
echo "  Press Ctrl+C to stop"
echo ""
echo -e "${BLUE}First-time setup:${NC}"
echo "  1. Create index pattern: logstash-*"
echo "  2. Time field: @timestamp"
echo "  3. Navigate to Discover"
echo ""

# Port-forward Kibana
kubectl port-forward -n logging svc/kibana-kibana 5601:5601
