#!/bin/bash

# Build and push Docker image to ECR with Git SHA tagging
# This script automates the container build and push workflow for the SRE Demo Service

set -e  # Exit on any error

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== SRE Demo Service - Build and Push to ECR ===${NC}\n"

# Get AWS account ID
echo -e "${YELLOW}Getting AWS account ID...${NC}"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo "Error: Unable to get AWS account ID. Is AWS CLI configured?"
    exit 1
fi
echo -e "${GREEN}AWS Account ID: ${AWS_ACCOUNT_ID}${NC}\n"

# Get AWS region (default to us-east-1 if not set)
AWS_REGION="${AWS_REGION:-us-east-1}"
echo -e "${GREEN}Using region: ${AWS_REGION}${NC}\n"

# Get current Git SHA
echo -e "${YELLOW}Getting Git SHA...${NC}"
GIT_SHA=$(git rev-parse --short HEAD)
if [ -z "$GIT_SHA" ]; then
    echo "Error: Unable to get Git SHA. Are you in a Git repository?"
    exit 1
fi
echo -e "${GREEN}Git SHA: ${GIT_SHA}${NC}\n"

# Define image details
REPO_NAME="sre-demo-service"
ECR_REPO="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPO_NAME}"
IMAGE_TAG_SHA="${ECR_REPO}:${GIT_SHA}"
IMAGE_TAG_LATEST="${ECR_REPO}:latest"

echo -e "${BLUE}Building Docker image...${NC}"
cd "$(dirname "$0")/../app"  # Navigate to app directory
docker build -t ${REPO_NAME}:${GIT_SHA} -t ${REPO_NAME}:latest .
echo -e "${GREEN}Image built successfully${NC}\n"

# Tag images for ECR
echo -e "${BLUE}Tagging images for ECR...${NC}"
docker tag ${REPO_NAME}:${GIT_SHA} ${IMAGE_TAG_SHA}
docker tag ${REPO_NAME}:latest ${IMAGE_TAG_LATEST}
echo -e "${GREEN}Images tagged${NC}\n"

# Authenticate to ECR
echo -e "${YELLOW}Authenticating to ECR...${NC}"
aws ecr get-login-password --region ${AWS_REGION} | \
    docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
echo -e "${GREEN}Authenticated${NC}\n"

# Push images to ECR
echo -e "${BLUE}Pushing images to ECR...${NC}"
docker push ${IMAGE_TAG_SHA}
docker push ${IMAGE_TAG_LATEST}
echo -e "${GREEN}Images pushed successfully${NC}\n"

# Display summary
echo -e "${GREEN}===========================================${NC}"
echo -e "${GREEN}Build and Push Complete${NC}"
echo -e "${GREEN}===========================================${NC}"
echo -e "Git SHA:      ${GIT_SHA}"
echo -e "ECR Repo:     ${ECR_REPO}"
echo -e "Image Tags:"
echo -e "  - ${IMAGE_TAG_SHA}"
echo -e "  - ${IMAGE_TAG_LATEST}"
echo -e "\n${BLUE}To pull the image:${NC}"
echo -e "  docker pull ${IMAGE_TAG_LATEST}"
echo -e "\n${BLUE}To run the container:${NC}"
echo -e "  docker run -d -p 8080:8080 -p 6060:6060 ${IMAGE_TAG_LATEST}"
echo -e "  curl http://localhost:8080/health"
