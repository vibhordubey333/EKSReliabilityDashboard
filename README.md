# EKS Reliability Dashboard

A production-ready AWS EKS demonstration project showcasing Site Reliability Engineering (SRE) principles and best practices for multi-environment Kubernetes deployments.

## Project Overview

This project demonstrates:
- **Multi-environment isolation** using Kubernetes namespaces (dev, qa, prod)
- **RBAC security model** with graduated permissions
- **Infrastructure as Code** using eksctl
- **SRE best practices** including observability, resource management, and cost optimization
- **Automated deployment and validation** workflows

## Prerequisites

Before you begin, ensure you have:

- **AWS Account** with appropriate permissions (EKS, EC2, VPC, IAM)
- **AWS CLI** installed and configured (`aws configure`)
- **eksctl** (>= 0.150.0)
- **kubectl** (>= 1.27)
- **Basic understanding** of Kubernetes and AWS

### Installation Commands

```bash
# macOS
brew install eksctl kubectl awscli

# Linux - eksctl
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

# Linux - kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/vibhordubey333/EKSReliabilityDashboard.git
cd EKSReliabilityDashboard
```

### 2. Create the EKS Cluster

```bash
./scripts/setup-cluster.sh
```

This script will:
- Validate prerequisites
- Create EKS cluster in us-east-1
- Create dev, qa, prod namespaces
- Apply RBAC policies
- Deploy sample nginx application

**Estimated time: 15-20 minutes**

### 3. Validate the Cluster

```bash
./scripts/validate-cluster.sh
```

### 4. Explore the Cluster

```bash
# View nodes
kubectl get nodes -o wide

# View all namespaces
kubectl get namespaces

# View deployments in all namespaces
kubectl get deployments -A

# View pods in dev namespace
kubectl get pods -n dev

# Describe a pod
kubectl get pods -n dev
kubectl describe pod <pod-name> -n dev
```

## Project Structure

```
EKSReliabilityDashboard/
├── cluster-config.yaml           # eksctl cluster configuration
├── app/                          # SRE Demo Service (Go microservice)
│   ├── Dockerfile                # Multi-stage container build
│   ├── main.go                   # HTTP server
│   └── handlers/                 # Health, metrics, debug endpoints
├── k8s/
│   ├── namespaces/               # Namespace definitions with quotas
│   │   ├── dev-namespace.yaml
│   │   ├── qa-namespace.yaml
│   │   └── prod-namespace.yaml
│   ├── rbac/                     # RBAC policies
│   │   ├── dev-role.yaml
│   │   ├── qa-readonly-role.yaml
│   │   └── prod-limited-role.yaml
│   └── samples/                  # Sample applications
│       └── nginx-deployment.yaml
├── scripts/
│   ├── setup-cluster.sh          # Main setup orchestration
│   ├── validate-cluster.sh       # Cluster validation
│   ├── cleanup-cluster.sh        # Safe cluster deletion
│   └── build-and-push.sh         # Build and push to ECR
└── docs/
    └── CLUSTER-SETUP.md          # Detailed documentation
```

## Container Registry

The SRE Demo Service is containerized and stored in AWS ECR (Elastic Container Registry):

```
Repository: 911723818034.dkr.ecr.us-east-1.amazonaws.com/sre-demo-service
Region: us-east-1
```

### Quick Commands

```bash
# Authenticate to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin 911723818034.dkr.ecr.us-east-1.amazonaws.com

# Pull the latest image
docker pull 911723818034.dkr.ecr.us-east-1.amazonaws.com/sre-demo-service:latest

# Run the container
docker run -d -p 8080:8080 -p 6060:6060 \
  911723818034.dkr.ecr.us-east-1.amazonaws.com/sre-demo-service:latest

# Test the service
curl http://localhost:8080/health
```

For detailed container documentation, see [app/README.md](app/README.md).

## Mon itoring

The cluster includes Prometheus and Grafana for comprehensive monitoring and observability.

### Install Monitoring Stack

```bash
# Install Prometheus and Grafana
./scripts/install-monitoring.sh
```

### Access Grafana Dashboards

```bash
# Quick access
./scripts/access-grafana.sh

# Or manually
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Open http://localhost:3000
# Login: admin / admin123
```

### Access Prometheus

```bash
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# Open http://localhost:9090
```

### Verify Metrics Collection

```bash
# Check monitoring pods
kubectl get pods -n monitoring

# View metrics from SRE demo service
kubectl port-forward -n dev svc/sre-demo-service 8080:8080
curl http://localhost:8080/metrics
```

For detailed monitoring setup, see [docs/OBSERVABILITY.md](docs/OBSERVABILITY.md).

## Logging

The cluster includes **EFK Stack** (Elasticsearch, Fluent Bit, Kibana) for centralized log aggregation.

### Install Logging Stack

```bash
# Install Elasticsearch, Fluent Bit, and Kibana
./scripts/install-logging.sh
```

### Access Kibana

```bash
# Quick access
./scripts/access-kibana.sh

# Or manually
kubectl port-forward -n logging svc/kibana-kibana 5601:5601

# Open http://localhost:5601
# Create index pattern: logstash-*
```

### Query Logs

```
# Logs from dev namespace
kubernetes.namespace_name: "dev"

# Logs from specific pod
kubernetes.pod_name: "sre-demo-service-*"

# Error logs
level: "error"
```

For detailed logging documentation, see [docs/LOGGING.md](docs/LOGGING.md).

## Cost Optimization

This setup is optimized for **learning and demonstration**:

| Component | Type | Cost |
|-----------|------|------|
| EKS Control Plane | Managed | ~$73/month |
| Worker Nodes | 2 × t3.medium | ~$60/month |
| **Total** | | **~$133/month** |

### Cost-Saving Tips

1. **Shut down when not in use** (though you'll need to delete and recreate)
2. **Delete the cluster** after demos: `./scripts/cleanup-cluster.sh`
3. **Use spot instances** for non-critical workloads (can add in cluster config)
4. **Monitor with AWS Cost Explorer** to track spending

## Architecture

```
┌─────────────────────────────────────────────────────┐
│              AWS EKS Cluster                        │
│  (eks-reliability-demo - us-east-1)                │
├─────────────────────────────────────────────────────┤
│                                                      │
│  ┌──────────────┐  ┌──────────────┐               │
│  │   Node 1     │  │   Node 2     │               │
│  │  t3.small    │  │  t3.small    │               │
│  │  us-east-1a  │  │  us-east-1b  │               │
│  └──────────────┘  └──────────────┘               │
│         │                 │                         │
│  ┌──────┴─────────────────┴──────┐                │
│  │   Namespaces                   │                │
│  ├────────────────────────────────┤                │
│  │ dev   │ qa   │ prod            │                │
│  │ (5p)  │ (5p) │ (8p)            │                │
│  └────────────────────────────────┘                │
└─────────────────────────────────────────────────────┘

Legend: (Xp) = max pods per namespace
```

## Security & RBAC

### Namespace Permission Model

| Namespace | Permission Level | Use Case |
|-----------|-----------------|----------|
| **dev** | Full access | Development and experimentation |
| **qa** | Read-only | Testing and validation |
| **prod** | Deploy-only | Production deployments (no delete) |

### RBAC Roles

- **dev-full-access**: Complete CRUD operations in dev
- **qa-readonly**: View-only access in qa
- **prod-deployer**: Can deploy/update but not delete in prod

## Testing RBAC Permissions

```bash
# Check if you can create deployments in dev
kubectl auth can-i create deployments -n dev

# Check if you can delete pods in prod
kubectl auth can-i delete pods -n prod

# View roles in a namespace
kubectl get roles -n dev
kubectl describe role dev-full-access -n dev
```

## Observability

### CloudWatch Integration

This cluster has CloudWatch logging enabled for:
- API server logs
- Audit logs
- Controller manager logs
- Scheduler logs

View logs in AWS Console → CloudWatch → Log groups → `/aws/eks/eks-reliability-demo/cluster`

### Checking Resource Usage

```bash
# Node resource usage
kubectl top nodes

# Pod resource usage
kubectl top pods -A

# Resource quotas
kubectl get resourcequota -n dev
kubectl describe resourcequota dev-quota -n dev
```

## Cleanup

**IMPORTANT**: To avoid ongoing charges, delete the cluster when done:

```bash
./scripts/cleanup-cluster.sh
```

This will safely delete:
- All workloads and data
- Worker nodes
- EKS cluster
- Associated VPC resources

## Additional Resources

- [EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [eksctl Documentation](https://eksctl.io/)

## Learning Objectives

This project helps you learn:
- EKS cluster provisioning and management
- Kubernetes namespace isolation
- RBAC security model implementation
- Resource quotas and limits
- Health checks and probes
- Multi-AZ high availability
- Cost optimization strategies
- SRE operational best practices

## License

MIT License - See LICENSE file for details


---

**Questions or Issues?** Please open an issue in the repository.
