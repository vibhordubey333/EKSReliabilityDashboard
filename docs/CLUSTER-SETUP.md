# EKS Cluster Setup - Detailed Guide

## Overview

This document provides in-depth information about the EKS cluster setup, design decisions, and SRE principles demonstrated in this project.

## Table of Contents

1. [My Thought Process & Implementation Journey](#my-thought-process--implementation-journey)
2. [Cluster Configuration](#cluster-configuration)
3. [Multi-Environment Strategy](#multi-environment-strategy)
4. [RBAC Model](#rbac-model)
5. [Resource Management](#resource-management)
6. [High Availability](#high-availability)
7. [Security Considerations](#security-considerations)
8. [Troubleshooting](#troubleshooting)
9. [Interview Talking Points](#interview-talking-points)

---

## My Thought Process & Implementation Journey

> **For Interview**: Use this section if the interviewer asks "How did you approach this project?" or "Walk me through your thought process."

### Initial Requirements Analysis

**Given**: Build an EKS Reliability Dashboard demonstrating SRE principles

**My first questions**:
1. What environment separation strategy should I use?
2. How can I demonstrate SRE best practices within budget constraints?
3. What security model makes sense for multi-environment setup?
4. How do I make this production-ready but cost-effective?

### Step 1: Research & Planning (Day 1)

**What I did**:
- Researched EKS best practices from AWS documentation
- Studied SRE principles (SLIs/SLOs, error budgets, observability)
- Compared tools: eksctl vs Terraform vs AWS Console
- Analyzed cost implications of different instance types

**Key Decisions Made**:
- **Tool choice**: eksctl (faster for learning, AWS best practices built-in)
- **Environment strategy**: Namespaces (cost-effective, sufficient for demo)
- **Region**: us-east-1 (requested, familiar, lots of capacity)
- **Instance type**: t3.small (balance of cost vs capability)

**Interview Talking Point**:
> "I started by understanding the requirements and constraints. Since this was for learning and demonstration, I prioritized cost optimization while still following production best practices. I chose eksctl because it's purpose-built for EKS and handles many complexities automatically, though in a larger organization, I might choose Terraform for its multi-cloud capabilities and state management."

### Step 2: Architecture Design (Day 1)

**What I designed**:

```
┌─────────────────────────────────────────┐
│  Requirements                            │
│  - Multi-environment (dev/qa/prod)      │
│  - SRE best practices                    │
│  - Cost-optimized (~$100/month budget)  │
│  - Production-ready patterns            │
└─────────────────────────────────────────┘
                   ↓
┌─────────────────────────────────────────┐
│  Design Decisions                        │
│  ✓ Single cluster, 3 namespaces         │
│  ✓ Multi-AZ for HA (us-east-1a/1b)     │
│  ✓ Graduated RBAC (qa→prod→dev)        │
│  ✓ Resource quotas per namespace        │
│  ✓ CloudWatch logging enabled           │
└─────────────────────────────────────────┘
                   ↓
┌─────────────────────────────────────────┐
│  Implementation Plan                     │
│  1. Cluster config file                  │
│  2. Namespace manifests                  │
│  3. RBAC policies                        │
│  4. Sample application                   │
│  5. Automation scripts                   │
│  6. Documentation                        │
└─────────────────────────────────────────┘
```

**Interview Talking Point**:
> "I approached this systematically: requirements → design → implementation. I documented my decisions so I could explain the 'why' behind each choice. For example, I chose namespace isolation over separate clusters because it's 70% cheaper while still demonstrating the concepts of environment separation and RBAC."

### Step 3: Infrastructure Configuration (Day 1-2)

**Order of implementation**:

**a) Created `cluster-config.yaml` first**
- Why first? Foundation for everything else
- Decisions made:
  - **Kubernetes version 1.28** (latest stable) - Ensures access to newest features and security patches while maintaining stability
  - **2 nodes minimum for HA** - Minimum required for high availability; if one node fails, workloads continue on the other
  - **Enabled IRSA for AWS IAM integration** - Allows pods to assume IAM roles without hardcoding credentials, following security best practices
  - **CloudWatch logging for observability** - Captures audit trails and troubleshooting data; essential for compliance and incident response
  - **Single NAT gateway (cost optimization)** - Allows private subnet nodes to access internet (pull images, packages) while blocking inbound traffic; saves ~$32/month vs HA setup (one NAT per AZ); acceptable for learning but production needs multiple NAT Gateways for fault tolerance.

**b) Created namespace manifests**
- Why second? Logical isolation needed before deployments
- Created three files: `dev-namespace.yaml`, `qa-namespace.yaml`, `prod-namespace.yaml`
- Added ResourceQuotas to prevent resource exhaustion
- Added LimitRanges to provide defaults

**c) Created RBAC policies**
- Why third? Security before applications
- Implemented graduated permissions:
  - **dev-role.yaml: Full access (create, read, update, delete)**
    - Why full access? Developers need freedom to experiment, debug, and iterate quickly
    - Can delete failed pods, modify deployments, access logs, exec into containers
    - Mistakes here don't impact production - it's a safe learning environment
    - Enables rapid troubleshooting without waiting for permissions
  - **qa-readonly-role.yaml: Read-only (get, list, watch only)**
    - Why read-only? QA environment should be stable for testing
    - Prevents accidental modifications that could invalidate test results
    - Testers can view logs and pod status but can't change configurations
    - Ensures test environment consistency across test runs
  - **prod-limited-role.yaml: Deploy-only (create/update but NO delete)**
    - Why no delete? Prevents catastrophic accidents like deleting production databases
    - Can deploy new versions and update existing deployments
    - Cannot delete services, pods, or persistent data
    - Follows "break-glass" principle - destructive actions require higher approval

**d) Created sample application**
- Why fourth? Validate the infrastructure works
- `nginx-deployment.yaml` with:
  - Resource requests/limits
  - Liveness and readiness probes
  - Pod anti-affinity for HA

**Interview Talking Point**:
> "I followed a bottom-up approach: infrastructure → namespaces → security → applications. This mirrors how you'd build a real production cluster. You don't deploy apps before you have security policies in place. Each layer builds on the previous one."

### Step 4: Automation & DRY Principle (Day 2)

**Goal**: Reduce repetitive tasks with bash scripts

**Scripts Created:**

1. **[setup-cluster.sh](file:///Users/infinitelearner/Code-Repos/EKSReliabilityDashboard/scripts/setup-cluster.sh)** - Automated cluster creation
   - Validates prerequisites (eksctl, kubectl, AWS CLI)
   - Creates EKS cluster using eksctl
   - Deploys namespaces (dev, qa, prod)
   - Applies RBAC policies
   - Installs metrics-server for HPA

2. **[validate-cluster.sh](file:///Users/infinitelearner/Code-Repos/EKSReliabilityDashboard/scripts/validate-cluster.sh)** - Comprehensive validation
   - Checks node status, namespaces, RBAC, metrics-server
   - Validates 7 different aspects of cluster health

3. **[cleanup-cluster.sh](file:///Users/infinitelearner/Code-Repos/EKSReliabilityDashboard/scripts/cleanup-cluster.sh)** - Complete teardown
   - Uninstalls Helm releases (monitoring, logging)
   - Deletes PVCs and namespaces
   - Removes EKS cluster and ECR repository

4. **[build-and-push.sh](file:///Users/infinitelearner/Code-Repos/EKSReliabilityDashboard/scripts/build-and-push.sh)** - Docker automation
   - Creates ECR repository if needed
   - Builds Docker image with Git SHA tag
   - Pushes to ECR

5. **[install-monitoring.sh](file:///Users/infinitelearner/Code-Repos/EKSReliabilityDashboard/scripts/install-monitoring.sh)** - Prometheus & Grafana setup
   - Installs kube-prometheus-stack via Helm
   - Configures 7-day retention, persistent storage
   - Waits for pods and displays access instructions

6. **[install-logging.sh](file:///Users/infinitelearner/Code-Repos/EKSReliabilityDashboard/scripts/install-logging.sh)** - EFK stack setup
   - Installs Elasticsearch, Fluent Bit, Kibana
   - Configures log collection from all namespaces
   - Shows Kibana access commands

7. **[access-grafana.sh](file:///Users/infinitelearner/Code-Repos/EKSReliabilityDashboard/scripts/access-grafana.sh)** - Quick Grafana access
   - Port-forwards to localhost:3000
   - Displays credentials (admin/admin123)

8. **[access-kibana.sh](file:///Users/infinitelearner/Code-Repos/EKSReliabilityDashboard/scripts/access-kibana.sh)** - Quick Kibana access
   - Port-forwards to localhost:5601

9. **[setup-complete-demo.sh](file:///Users/infinitelearner/Code-Repos/EKSReliabilityDashboard/scripts/setup-complete-demo.sh)** - Full automation
   - Orchestrates: cluster → monitoring → logging → build → deploy
   - One-command complete setup (30-40 minutes)

**Key Principles Applied:**
- **DRY**: No manual commands repeated
- **Error handling**: `set -e`, `set -o pipefail`
- **Validation**: Pre-flight checks before execution
- **Idempotency**: Scripts can be run multiple times safely
- **User feedback**: Colored output (info, success, warning, error)
- **Modularity**: Each script has a single responsibility

**Interview Talking Point**:
> "As an SRE, I applied the DRY principle to these 9 scripts reduce deployment from 30+ minutes of manual work to one command. They also prevent human error - scripts never forget steps. The complete demo script orchestrates the entire stack, while individual scripts allow modular execution."


### Step 5: Documentation (Day 2)

**Why documentation matters**:
- Future me will forget the details
- Team members need to understand the system
- Reduces onboarding time
- Demonstrates communication skills

**What I documented**:
1. **README.md**: Quick start guide (minimal time to first success)
2. **CLUSTER-SETUP.md**: Deep dive (this file - the "why" behind decisions)
3. **Interview questions**: Anticipated questions based on implementation

**Interview Talking Point**:
> "Good documentation is part of being a good SRE. I write docs assuming the reader knows less than I do. The README gets someone started in 5 minutes. This detailed guide explains the 'why' behind each decision. Documentation IS part of the product."

### Step 6: Cost Optimization Decisions

**Budget constraint**: Need to minimize AWS spend

**Optimization strategies implemented**:
1. **Instance type**: t3.small instead of t3.medium → Save ~$30/month
2. **NAT gateway**: Single instead of HA → Save ~$30/month  
3. **Log retention**: 7 days instead of default 30 → Save on CloudWatch
4. **Volume size**: 20GB instead of default 80GB → Save on EBS
5. **Node count**: Start with 2, autoscale if needed

**Total savings**: ~$60/month vs a default setup

**Interview Talking Point**:
> "Cost optimization is a key SRE responsibility. I reduced costs by 40% while maintaining the learning value. In production, I'd analyze actual usage patterns and right-size resources accordingly. I'd also evaluate Reserved Instances for predictable workloads and Spot Instances for fault-tolerant jobs."

### Step 7: Security Best Practices

**What I implemented**:

1. **RBAC**: Principle of least privilege
   - Different permissions for different environments
   - Service accounts with scoped permissions

2. **.gitignore**: Prevent credential leaks
   - No kubeconfig files in git
   - No AWS credentials in git

3. **IAM integration**: IRSA enabled
   - Pods can assume IAM roles
   - No long-lived credentials in pods

4. **Audit logging**: CloudWatch
   - Track who did what and when
   - Required for compliance

**Interview Talking Point**:
> "Security is not an afterthought - it's built in from the start. I follow the principle of least privilege for RBAC. I use .gitignore to prevent credential leaks - a single leaked kubeconfig can compromise the entire cluster. Audit logging provides accountability and helps with incident response."

### Step 8: Testing & Validation

**How I validated**:
1. Tested eksctl config syntax before committing
2. Created validation script to check all components
3. Reviewed AWS best practices documentation
4. Planned manual deployment test before interview

**Interview Talking Point**:
> "I believe in 'trust but verify'. The validation script checks 7 different aspects of cluster health. I plan to do a full deployment test before the interview to ensure everything works as expected."

---

## Real Interview Scenario: "Walk me through your approach"

**Question**: "I see you built an EKS cluster. Can you walk me through how you approached this?"

**Your Answer Template**:

> "Sure! Let me walk you through my thought process.
>
> **Step 1 - Requirements gathering**: I identified the core requirements: multi-environment separation, SRE best practices, and cost optimization since this is for learning.
>
> **Step 2 - Research & tool selection**: I evaluated eksctl vs Terraform. I chose eksctl because it's purpose-built for EKS and follows AWS best practices automatically. For a larger infrastructure project, I'd likely use Terraform for better state management.
>
> **Step 3 - Architecture design**: I designed a single cluster with namespace isolation for dev/qa/prod. This is cost-effective for a demo while still showing environment separation. In production, I'd likely isolate prod into its own cluster for stronger security boundaries.
>
> **Step 4 - Security-first implementation**: I started with RBAC policies implementing least-privilege access. Dev gets full access, QA is read-only, and prod allows deployments but not deletions - mimicking real-world restrictions.
>
> **Step 5 - Observability**: I enabled CloudWatch logging for audit trails and included health probes in the sample deployment for self-healing.
>
> **Step 6 - Automation**: I scripted the entire deployment process. As an SRE, I automate anything done more than once to reduce human error and ensure repeatability.
>
> **Step 7 - Cost optimization**: I chose t3.small instances and a single NAT gateway, reducing costs by ~40% while maintaining the learning objectives.
>
> **Step 8 - Documentation**: I documented everything - not just what I did, but why. Good documentation reduces onboarding time and prevents knowledge silos.
>
> The result is a production-ready cluster that demonstrates SRE principles while staying within a reasonable budget for learning."

---

## Cluster Configuration

### Why eksctl?

**Decision**: We use eksctl instead of manual AWS Console or Terraform for the initial setup.

**Rationale**:
- **Speed**: Fastest way to create a production-ready cluster
- **Best practices**: Automatically follows AWS and Kubernetes best practices
- **Declarative**: YAML configuration is version-controlled
- **AWS-optimized**: Built specifically for EKS

**Tradeoffs**:
- Less flexibility than Terraform for complex infrastructure
- AWS-specific (not cloud-agnostic)

### Cluster Specifications

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Region | us-east-1 | As requested, high availability region |
| K8s Version | 1.28 | Latest stable version |
| Instance Type | t3.small | Cost-optimized (2 vCPU, 2 GiB RAM) |
| Node Count | 2 (1-3) | Minimum for HA, autoscaling enabled |
| AZs | us-east-1a, us-east-1b | Multi-AZ for fault tolerance |
| NAT Gateway | Single | Cost optimization (not HA) |

### NAT Gateway: Single vs High Availability (HA) Setup

**What is a NAT Gateway?**

NAT Gateway = Network Address Translation Gateway. It's a networking component that allows resources in **private subnets** to access the internet while **blocking inbound traffic** from the internet.

**Why do we need it?**

Your EKS worker nodes live in private subnets (for security). But they need to:
- Pull container images from Docker Hub, ECR
- Download software packages and updates
- Access AWS services (S3, DynamoDB, etc.)
- Make outbound API calls

Without a NAT Gateway, your private nodes have NO internet access.

---

**Option 1: High Availability (HA) Setup - Production Best Practice**

```
Region: us-east-1
┌─────────────────────────────────────────────────────────┐
│                                                          │
│  Availability Zone 1a          Availability Zone 1b     │
│  ┌──────────────────┐         ┌──────────────────┐     │
│  │ Public Subnet    │         │ Public Subnet    │     │
│  │ NAT Gateway #1   │         │ NAT Gateway #2   │     │
│  │ ($32/month)      │         │ ($32/month)      │     │
│  └────────┬─────────┘         └────────┬─────────┘     │
│           │                            │                │
│  ┌────────▼─────────┐         ┌───────▼──────────┐     │
│  │ Private Subnet   │         │ Private Subnet   │     │
│  │ Worker Node 1    │         │ Worker Node 2    │     │
│  │ Uses NAT in 1a   │         │ Uses NAT in 1b   │     │
│  └──────────────────┘         └──────────────────┘     │
│                                                          │
└─────────────────────────────────────────────────────────┘

Total Cost: ~$64/month (2 NAT Gateways)
Fault Tolerance: If AZ-1a fails, nodes in AZ-1b still have internet access
```

**How it works:**
- Each availability zone has its own NAT Gateway
- Nodes in AZ-1a use NAT Gateway in AZ-1a
- Nodes in AZ-1b use NAT Gateway in AZ-1b
- If one AZ fails completely, the other AZ remains functional

---

**Option 2: Single NAT Gateway - Cost-Optimized (Our Choice)**

```
Region: us-east-1
┌─────────────────────────────────────────────────────────┐
│                                                          │
│  Availability Zone 1a          Availability Zone 1b     │
│  ┌──────────────────┐         ┌──────────────────┐     │
│  │ Public Subnet    │         │ Public Subnet    │     │
│  │ NAT Gateway      │         │ (no NAT)         │     │
│  │ ($32/month)      │         │                  │     │
│  └────────┬─────────┘         └──────────────────┘     │
│           │                            │                │
│           │   ┌────────────────────────┘                │
│           │   │                                         │
│  ┌────────▼───▼─────┐         ┌──────────────────┐     │
│  │ Private Subnet   │         │ Private Subnet   │     │
│  │ Worker Node 1    │         │ Worker Node 2    │     │
│  │ Uses NAT in 1a   │         │ Uses NAT in 1a   │     │
│  └──────────────────┘         └──────────────────┘     │
│                                                          │
└─────────────────────────────────────────────────────────┘

Total Cost: ~$32/month (1 NAT Gateway)
Risk: If AZ-1a fails, ALL nodes lose internet access
```

**How it works:**
- Only one NAT Gateway in AZ-1a
- ALL nodes (in both AZ-1a and AZ-1b) route through this single NAT
- Cross-AZ data transfer from AZ-1b to AZ-1a (small additional cost)
- If AZ-1a fails, nodes in BOTH zones lose internet access

---

**Why We Chose Single NAT Gateway:**

| Factor | Single NAT | HA NAT |
|--------|-----------|--------|
| **Cost** | ~$32/month | ~$64/month |
| **Savings** | 50% cheaper | - |
| **Fault Tolerance** | Low - single point of failure | High - survives AZ failure |
| **Acceptable For** | Dev, Learning, Non-critical | Production, Business-critical |
| **Our Use Case** | Learning/Demo project | - |

**Interview Talking Point:**
> "For this learning environment, I chose a single NAT Gateway to reduce costs by 50% (~$32/month vs ~$64/month). This creates a single point of failure - if that availability zone goes down, all nodes lose internet connectivity. However, this is an acceptable tradeoff for a non-production learning environment. In production, I would absolutely use multiple NAT Gateways (one per AZ) to ensure high availability and fault tolerance, even though it doubles the cost."

## Multi-Environment Strategy

### Namespace Isolation

We use **namespaces** for environment separation rather than separate clusters.

#### Advantages
- **Cost-effective**: Single control plane
- **Resource sharing**: Better utilization
- **Simpler operations**: One cluster to manage
- **Fast environment creation**: Just create a namespace

#### Limitations
- **Weaker isolation**: Not as strong as cluster-level separation
- **Shared resources**: Potential for "noisy neighbor" issues
- **Security**: Same RBAC system, easier to misconfigure

### When to Use Separate Clusters

In production, consider separate clusters for:
- **Strict compliance** requirements
- **Different scaling** characteristics
- **Blast radius containment** (isolate prod completely)
- **Multi-tenancy** with different teams/customers

## RBAC Model

### Permission Hierarchy

```
Least Privilege → Most Privilege

qa (read-only) → prod (deploy-only) → dev (full-access)
```

### Design Philosophy

1. **Default deny**: Start with no permissions, grant as needed
2. **Namespace-scoped**: Use Roles, not ClusterRoles when possible
3. **Principle of least privilege**: Grant minimum necessary permissions
4. **Graduated access**: More restrictions in production environments

### RBAC Components

#### Dev Namespace - Full Access
```yaml
Role: dev-full-access
Subjects: dev-users group, default SA
Permissions: Full CRUD on most resources
Use case: Rapid development and experimentation
```

#### QA Namespace - Read-Only
```yaml
Role: qa-readonly
Subjects: qa-readonly-users group
Permissions: get, list, watch only
Use case: Testing and validation without modifications
```

#### Prod Namespace - Deploy-Only
```yaml
Role: prod-deployer
Subjects: prod-deployers group, default SA
Permissions: Create/update deployments, NO delete
```

### How RoleBinding Works

**RBAC = Role-Based Access Control** consists of two main parts that work together:

1. **Role**: Defines WHAT actions are allowed (permissions)
2. **RoleBinding**: Defines WHO can perform those actions (connects users to roles)

Think of it like a building:
- **Role** = The key that opens certain doors
- **RoleBinding** = Giving that key to specific people

---

**The Complete Flow:**

```
User/Group/ServiceAccount  →  RoleBinding  →  Role  →  Kubernetes Resources
      (WHO)                   (CONNECTION)    (WHAT)      (WHERE)
```

---

**Real Example from Our Project:**

Let's break down dev-role.yaml:

```yaml
# PART 1: Define the Role (WHAT permissions)
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: dev-full-access        # Name of this role
  namespace: dev               # Only applies to 'dev' namespace
rules:
- apiGroups: ["", "apps"]      # Which API groups
  resources:                    # Which resources
    - pods
    - deployments
    - services
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
                                # What actions are allowed
---
# PART 2: Create the RoleBinding (WHO gets these permissions)
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: dev-full-access-binding
  namespace: dev               # Must be same namespace as Role
roleRef:                        # Which Role to grant
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: dev-full-access        # Points to the Role above
subjects:                       # WHO gets this role
- kind: Group
  name: dev-users              # Group of developers
  apiGroup: rbac.authorization.k8s.io
- kind: ServiceAccount
  name: default                # Default service account in namespace
  namespace: dev
```

---

**How It Works Step-by-Step:**

**Step 1: User makes a request**
```bash
kubectl create deployment nginx --image=nginx -n dev
```

**Step 2: Kubernetes checks the RoleBinding**
- "Is this user a member of any subjects in a RoleBinding?"
- Finds: User is in "dev-users" group
- RoleBinding says: "dev-users" group is bound to "dev-full-access" role

**Step 3: Kubernetes checks the Role**
- "What can the dev-full-access role do?"
- Role says: "Can create deployments in dev namespace"

**Step 4: Decision**
- ✅ **ALLOW** - User can create the deployment

---

**Different Subjects (WHO can be granted permissions):**

1. **User**: Individual person
   ```yaml
   subjects:
   - kind: User
     name: alice@example.com
     apiGroup: rbac.authorization.k8s.io
   ```

2. **Group**: Collection of users (what we use)
   ```yaml
   subjects:
   - kind: Group
     name: dev-users
     apiGroup: rbac.authorization.k8s.io
   ```

3. **ServiceAccount**: For pods/applications
   ```yaml
   subjects:
   - kind: ServiceAccount
     name: default
     namespace: dev
   ```

---

**Why We Use Groups:**

Instead of:
```yaml
# BAD: Bind role to individual users
subjects:
- kind: User
  name: alice
- kind: User
  name: bob
- kind: User
  name: charlie
```

We do:
```yaml
# GOOD: Bind role to a group
subjects:
- kind: Group
  name: dev-users
```

**Benefits:**
- Add new developer → Just add to dev-users group
- Remove developer → Remove from group
- Don't need to update RoleBinding for every hire/departure

---

**Our Three Examples:**

| Namespace | RoleBinding | Connects | To Role | Result |
|-----------|-------------|----------|---------|--------|
| **dev** | dev-full-access-binding | dev-users group | dev-full-access | Developers get full CRUD |
| **qa** | qa-readonly-binding | qa-readonly-users | qa-readonly | QA team gets read-only |
| **prod** | prod-deployer-binding | prod-deployers | prod-deployer | Deploy team can deploy, not delete |

---

**Testing RoleBinding:**

```bash
# Check what you can do
kubectl auth can-i create deployments -n dev
# Output: yes (if you're in dev-users group)

kubectl auth can-i delete pods -n prod
# Output: no (prod-deployer role doesn't allow delete)

# Check for a specific user
kubectl auth can-i create pods -n qa --as=alice@example.com
# Tests if alice can create pods in qa
```

---

**Common Interview Questions:**

**Q: What's the difference between Role and RoleBinding?**
> "A Role defines WHAT actions are allowed on which resources. A RoleBinding connects WHO (users, groups, service accounts) to that Role. You can have a Role without a RoleBinding (no one can use it), but you can't have a RoleBinding without a Role (nothing to grant)."

**Q: What's the difference between Role and ClusterRole?**
> "Role is namespace-scoped - it only applies to one namespace. ClusterRole is cluster-wide and can grant permissions across all namespaces or to cluster-level resources like nodes. For security, I use Roles when possible (principle of least privilege)."

**Q: Why use RoleBinding instead of just hardcoding permissions in the deployment?**
> "RoleBinding separates WHO from WHAT, making it easier to manage. I can change permissions for all developers by editing one Role, instead of modifying every deployment. It also follows the principle of least privilege - users only get access they need for specific namespaces."

## Resource Management


### Resource Quotas

Each namespace has ResourceQuota objects to prevent resource exhaustion:

| Namespace | CPU | Memory | Pods | PVCs |
|-----------|-----|--------|------|------|
| dev | 1 core | 1 GiB | 5 | 2 |
| qa | 1 core | 1 GiB | 5 | 2 |
| prod | 2 cores | 2 GiB | 8 | 4 |

### LimitRanges

LimitRange objects enforce default and maximum resource limits per container:

**Example - Dev Namespace**:
- **Default request**: 100m CPU, 128Mi memory
- **Default limit**: 200m CPU, 256Mi memory
- **Maximum**: 500m CPU, 512Mi memory
- **Minimum**: 50m CPU, 64Mi memory

### Why This Matters

1. **Prevents resource starvation**: One app can't consume all cluster resources
2. **Enables scheduling**: Kubernetes knows where pods can fit
3. **Cost control**: Limits cloud spending
4. **Improves reliability**: Prevents OOM kills and CPU throttling

### Horizontal Pod Autoscaling (HPA)

**What is HPA?**

Horizontal Pod Autoscaler automatically scales the number of pods based on observed metrics (CPU, memory, or custom metrics). It increases pods during high load and decreases them when load is low.

---

**Our HPA Configuration:**

From [k8s/deployments/dev/hpa.yaml](file:///Users/infinitelearner/Code-Repos/EKSReliabilityDashboard/k8s/deployments/dev/hpa.yaml):

```yaml
spec:
  scaleTargetRef:
    kind: Deployment
    name: sre-demo-service
  minReplicas: 2
  maxReplicas: 5
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70    # Scale when average CPU > 70%
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300    # Wait 5 minutes before scaling down
      policies:
      - type: Percent
        value: 50                         # Remove max 50% of pods
        periodSeconds: 15                 # Every 15 seconds
    scaleUp:
      stabilizationWindowSeconds: 0       # Scale up immediately
      policies:
      - type: Percent
        value: 100                        # Can double pod count
        periodSeconds: 15
      - type: Pods
        value: 2                          # Or add 2 pods
        periodSeconds: 15
      selectPolicy: Max                   # Use whichever adds more pods
```

---

**Understanding stabilizationWindowSeconds:**

**Purpose**: Prevents "flapping" - rapid scaling up and down that wastes resources and causes instability.

**How It Works:**

**For Scale Down (300 seconds = 5 minutes):**
```
Timeline:
00:00 - CPU drops to 50% (below 70% threshold)
      - HPA thinks: "Maybe scale down?"
      - Action: WAIT (stabilization window)

01:00 - CPU still at 50%
      - HPA: "Still waiting..."

02:30 - CPU spikes to 80%
      - HPA: "Reset the window! Don't scale down"

05:00 - CPU steady at 50% for full 5 minutes
      - HPA: "Now it's safe to scale down"
      - Action: Remove 1 pod (50% policy = from 2 to 1)
```

**Visual:**
```
CPU Usage Over Time:
100%│                    ╱╲
    │         ╱╲        ╱  ╲
 70%│────────╱──╲──────╱────╲────────  (threshold)
    │       ╱    ╲    ╱      ╲
 50%│      ╱      ╲──╱        ╲───────
    │     ╱                    
  0%│────┴────────────────────────────
     0   1    2    3    4    5    6   (minutes)
         ↑                       ↑
         │                       └─ Scale down happens here
         └─ CPU drops, but HPA waits 5 minutes
```

**For Scale Up (0 seconds = immediate):**
```
Timeline:
00:00 - CPU jumps to 85% (above 70% threshold)
      - HPA: "Need more capacity NOW"
      - Action: IMMEDIATELY add pods (no wait)
```

**Why Different Values?**

| Direction | Window | Reason |
|-----------|--------|--------|
| **Scale Up** | 0 seconds (immediate) | Users experiencing slow response need help NOW |
| **Scale Down** | 300 seconds (5 min) | Avoid removing pods during temporary dips |

---

**Real-World Scenario:**

**Without Stabilization Window (BAD):**
```
Traffic Pattern: Spiky (common in web apps)
09:00 - 100 requests/sec → 2 pods
09:01 - 200 requests/sec → Scale to 4 pods
09:02 - 150 requests/sec → Scale to 3 pods
09:03 - 180 requests/sec → Scale to 4 pods
09:04 - 140 requests/sec → Scale to 3 pods

Problem: Constant scaling up and down
- Wastes resources (pod startup overhead)
- Causes brief outages during scaling
- Increases cloud costs (charged per second)
- Stresses Kubernetes API
```

**With Stabilization Window (GOOD):**
```
Traffic Pattern: Same spiky pattern
09:00 - 100 requests/sec → 2 pods
09:01 - 200 requests/sec → Immediately scale to 4 pods (scaleUp)
09:02 - 150 requests/sec → Keep 4 pods (wait for 5 min window)
09:03 - 180 requests/sec → Keep 4 pods (still waiting)
09:04 - 140 requests/sec → Keep 4 pods (still waiting)
...
09:06 - Steady at 140/sec for 5 min → Scale down to 3 pods

Benefit: More stable, fewer scaling events
```

---

**Scaling Policies Explained:**

Our HPA has two policies for scale-up:

1. **Percent Policy**: Add up to 100% of current pods
   - 2 pods → can scale to 4 pods
   - 4 pods → can scale to 8 pods (but max is 5)

2. **Pods Policy**: Add up to 2 pods at once
   - Current: 2 pods → can scale to 4 pods
   - Current: 3 pods → can scale to 5 pods

**selectPolicy: Max** means use whichever adds MORE pods.

**Example:**
```
Current: 2 pods, CPU at 90%

Option 1 (Percent): 2 + 100% = 4 pods
Option 2 (Pods):    2 + 2    = 4 pods
Result: Scale to 4 pods (both give same result)

Current: 3 pods, CPU at 90%

Option 1 (Percent): 3 + 100% = 6 pods (but max is 5)
Option 2 (Pods):    3 + 2    = 5 pods
Result: Scale to 5 pods (Max policy chooses Pods=5)
```

---

**Testing HPA:**

```bash
# Deploy and check HPA
kubectl apply -f k8s/deployments/dev/hpa.yaml
kubectl get hpa -n dev

# Watch HPA status (updates every 15 seconds)
kubectl get hpa -n dev -w

# Generate CPU load to trigger scaling
kubectl run -n dev load-generator --image=busybox --restart=Never -- \
  /bin/sh -c "while true; do wget -q -O- http://sre-demo-service:8080/cpu?duration=5000; done"

# Watch pods scale
kubectl get pods -n dev -l app=sre-demo-service -w

# Clean up
kubectl delete pod load-generator -n dev
```

**Expected Output:**
```bash
$ kubectl get hpa -n dev

NAME               REFERENCE                     TARGETS   MINPODS   MAXPODS   REPLICAS
sre-demo-service   Deployment/sre-demo-service   15%/70%   2         5         2

# After load generation
NAME               REFERENCE                     TARGETS   MINPODS   MAXPODS   REPLICAS
sre-demo-service   Deployment/sre-demo-service   85%/70%   2         5         4

# 5 minutes after load stops
NAME               REFERENCE                     TARGETS   MINPODS   MAXPODS   REPLICAS
sre-demo-service   Deployment/sre-demo-service   20%/70%   2         5         2
```

---

**Common Issues:**

**Problem: HPA shows `<unknown>/70%` for targets**
```bash
# Cause: metrics-server not installed or not working
# Solution:
kubectl get deployment metrics-server -n kube-system

# If missing, install:
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Wait 2-3 minutes for metrics to populate
```

**Problem: HPA doesn't scale down**
```bash
# Possible causes:
# 1. Still within stabilization window (wait 5 minutes)
# 2. CPU still above 70%
# 3. Already at minReplicas (2)

# Check current metrics:
kubectl top pods -n dev -l app=sre-demo-service
```

---

**Interview Talking Points:**

**Q: Why use a 5-minute stabilization window for scale-down?**

> "I chose 5 minutes because it balances resource efficiency with stability. Web traffic often has short spikes - if we scale down too quickly, we'll immediately scale back up when the next spike hits. This causes 'flapping' which wastes resources and can cause brief service disruptions during pod termination. Industry best practice is 3-5 minutes for scale-down. For scale-up, I use 0 seconds because when users are experiencing slow response times, they need relief immediately."

**Q: What's the difference between HPA and VPA?**

> "HPA (Horizontal Pod Autoscaler) adds or removes pods - scaling horizontally. VPA (Vertical Pod Autoscaler) changes the CPU/memory requests of existing pods - scaling vertically. I use HPA for stateless services like web apps because it's faster and more suitable for handling traffic bursts. VPA is better for stateful workloads like databases where you can't easily add replicas. You generally don't use both on the same deployment as they can conflict."

**Q: How does this relate to SRE and SLOs?**

> "HPA directly supports SLO targets. For example, if my SLO is '95% of requests complete in under 200ms', high CPU usage will cause latency spikes that violate this. HPA detects the CPU increase and adds capacity before the SLO is breached. The stabilization window prevents over-correction - we don't want to remove resources during a temporary lull, only to breach the SLO when traffic returns. This is proactive capacity management, a core SRE practice."

**Q: What metrics would you use instead of CPU?**

> "CPU is a good default for compute-intensive workloads, but I'd consider custom metrics based on the application: \n
> - Request rate (requests per second) for API services \n
> - Queue depth for message processors \n
> - Active connections for WebSocket services \n
> - Memory for caching layers \n
> These application-specific metrics often predict capacity needs better than CPU. You'd expose them via Prometheus and use a custom metrics adapter for HPA."

## High Availability

### Multi-AZ Deployment

- **Control plane**: AWS manages across 3 AZs automatically
- **Worker nodes**: Spread across us-east-1a and us-east-1b
- **Pod distribution**: Anti-affinity rules in sample deployment

### Pod Anti-Affinity for High Availability

**What is Pod Anti-Affinity?**

Pod anti-affinity is a Kubernetes scheduling rule that tells the scheduler to **spread pods apart** from each other across different nodes or availability zones. It's the opposite of pod affinity (which keeps pods together).

---

**Why It Matters for High Availability:**

Without anti-affinity, Kubernetes might schedule all your replicas on the same node:

```
Scenario WITHOUT Anti-Affinity:
┌──────────────────────┐  ┌──────────────────────┐
│   Node 1 (us-east-1a) │  │   Node 2 (us-east-1b) │
│                       │  │                       │
│  ┌─────┐  ┌─────┐    │  │                       │
│  │Pod 1│  │Pod 2│    │  │     (empty)           │
│  └─────┘  └─────┘    │  │                       │
│                       │  │                       │
└──────────────────────┘  └──────────────────────┘

Problem: If Node 1 fails → BOTH pods die → 100% outage
```

With anti-affinity, pods spread across nodes:

```
Scenario WITH Anti-Affinity:
┌──────────────────────┐  ┌──────────────────────┐
│   Node 1 (us-east-1a) │  │   Node 2 (us-east-1b) │
│                       │  │                       │
│      ┌─────┐          │  │      ┌─────┐          │
│      │Pod 1│          │  │      │Pod 2│          │
│      └─────┘          │  │      └─────┘          │
│                       │  │                       │
└──────────────────────┘  └──────────────────────┘

Benefit: If Node 1 fails → Pod 2 survives → 50% capacity maintained
```

---

**Configuration Types:**

There are two types of anti-affinity rules:

1. **`requiredDuringSchedulingIgnoredDuringExecution`** (Hard Rule)
   - **Must** follow the rule or pod won't be scheduled at all
   - Use when: Strict separation is critical (e.g., compliance requirements)
   - Risk: If only 1 node available, pods stay pending

2. **`preferredDuringSchedulingIgnoredDuringExecution`** (Soft Rule) - **We Use This**
   - **Try** to follow the rule, but schedule anyway if impossible
   - Use when: HA is desired but not critical, or limited node capacity
   - Benefit: Ensures pods always run, even in degraded configuration

---

**Our Configuration Example:**

From [k8s/deployments/dev/deployment.yaml](file:///Users/infinitelearner/Code-Repos/EKSReliabilityDashboard/k8s/deployments/dev/deployment.yaml):

```yaml
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100                    # Priority (0-100, higher = stronger preference)
      podAffinityTerm:
        labelSelector:
          matchExpressions:
          - key: app
            operator: In
            values:
            - sre-demo-service       # Avoid pods with this label
        topologyKey: kubernetes.io/hostname  # Spread across different hostnames (nodes)
```

**How It Works:**

1. **`labelSelector`**: Identifies which pods to spread apart (pods with `app=sre-demo-service`)
2. **`topologyKey`**: Defines the spread domain
   - `kubernetes.io/hostname` = spread across different nodes
   - `topology.kubernetes.io/zone` = spread across different AZs
   - `topology.kubernetes.io/region` = spread across different regions
3. **`weight: 100`**: Strong preference (0-100 scale)

**Example Flow:**

```
Step 1: Scheduler needs to place Pod 2 of sre-demo-service
Step 2: Check - where is Pod 1?
        → Pod 1 is on Node A
Step 3: Anti-affinity rule says "avoid nodes with sre-demo-service pods"
        → Prefers to schedule on Node B
Step 4: Node B has resources?
        → Yes: Schedule on Node B (spread achieved)
        → No: Schedule on Node A anyway (preferred, not required)
```

---

**Understanding "IgnoredDuringExecution":**

Both rule types end with `IgnoredDuringExecution`. This means:

- **During scheduling**: Rule is enforced (pods placed according to rule)
- **After deployment**: Rule is ignored (pods won't be moved if rule is violated)

**Example:**
```
1. Deploy 2 pods with anti-affinity → They spread across Node A and Node B
2. Node B fails → Pod on Node B restarts on Node A (now both on same node)
3. System does NOT automatically move pods back when Node B recovers
4. You must manually trigger a rolling restart to re-spread
```

---

**Real-World Scenarios:**

| Scenario | Rule Type | Topology Key | Example |
|----------|-----------|--------------|---------|
| **Database replicas across zones** | Required | `topology.kubernetes.io/zone` | PostgreSQL master/replicas |
| **Web app across nodes** | Preferred | `kubernetes.io/hostname` | Our SRE demo service |
| **Avoid same rack** | Required | Custom label `rack` | Hardware failure isolation |
| **Prefer different regions** | Preferred | `topology.kubernetes.io/region` | Global CDN nodes |

---

**Testing Anti-Affinity:**

```bash
# Deploy the service
kubectl apply -f k8s/deployments/dev/deployment.yaml

# Check which nodes pods are on
kubectl get pods -n dev -l app=sre-demo-service -o wide

# Expected output:
# NAME                    NODE
# sre-demo-service-abc    ip-10-0-1-100.ec2.internal  (Node in us-east-1a)
# sre-demo-service-xyz    ip-10-0-2-200.ec2.internal  (Node in us-east-1b)

# Verify anti-affinity is working
kubectl get pod sre-demo-service-abc -n dev -o yaml | grep -A 20 affinity
```

---

**Interview Talking Points:**

**Q: Why use preferred instead of required anti-affinity?**

> "I use preferred anti-affinity because it balances high availability with operational flexibility. With a required rule, if we only have one node available (during maintenance or scaling down), pods would stay pending and the service would be unavailable. Preferred ensures pods always run while still achieving separation when possible. For critical production databases, I'd use required anti-affinity across zones."

**Q: What happens if a node with multiple pods fails?**

> "If we have preferred anti-affinity and a node fails, Kubernetes reschedules the failed pods. They might land on the same node temporarily, reducing HA. The anti-affinity rule only applies during initial scheduling, not during rescheduling (due to 'IgnoredDuringExecution'). To restore proper distribution, I'd trigger a rolling restart after the cluster stabilizes."

**Q: How does this relate to SRE principles?**

> "Pod anti-affinity is a key reliability pattern. It reduces blast radius - a single node failure only affects a portion of your service. This directly contributes to availability SLOs. For a service targeting 99.9% uptime (43 minutes downtime/month), proper pod distribution can be the difference between meeting and missing that target when infrastructure fails."

### Health Checks

Sample deployment includes:

**Liveness Probe**:
```yaml
livenessProbe:
  httpGet:
    path: /
    port: 80
  initialDelaySeconds: 10
  periodSeconds: 10
```
- Detects if container is dead → Restarts automatically

**Readiness Probe**:
```yaml
readinessProbe:
  httpGet:
    path: /
    port: 80
  initialDelaySeconds: 5
  periodSeconds: 5
```
- Detects if container can serve traffic → Removes from Service endpoints

## Observability Stack

The cluster includes comprehensive monitoring using **kube-prometheus-stack** (Prometheus + Grafana).

**Quick Start:**
```bash
# Install monitoring stack
./scripts/install-monitoring.sh

# Access Grafana
./scripts/access-grafana.sh
# Open http://localhost:3000
# Login: admin / admin123
```

**What You Get:**
- **Prometheus**: Time-series metrics storage with 7-day retention
- **Grafana**: 20+ pre-configured Kubernetes dashboards
- **Metrics**: Cluster, node, pod, and application metrics
- **Custom Dashboards**: Create visualizations for SLIs/SLOs

**For detailed documentation, see [OBSERVABILITY.md](OBSERVABILITY.md)**

Topics covered:
- Complete installation guide
- Configuration details
- PromQL query examples
- Custom dashboard creation
- Alerting setup
- Troubleshooting
- Interview talking points

## Security Considerations

### Network Security
- **VPC isolation**: Worker nodes in private subnets
- **Security groups**: Automatically configured by EKS
- **Future enhancement**: NetworkPolicies for pod-to-pod security

### IAM Integration
- **IRSA enabled**: IAM Roles for Service Accounts
- **Node IAM roles**: Scoped permissions for AWS resource access
- **Audit logging**: CloudWatch logs for cluster API calls

### Secrets Management
- **Don't commit secrets**: .gitignore includes secret patterns
- **Future enhancement**: AWS Secrets Manager or External Secrets Operator

## Troubleshooting

### Common Issues

#### 1. Cluster creation fails

**Symptoms**: eksctl fails with VPC or IAM errors

**Solutions**:
- Check AWS credentials: `aws sts get-caller-identity` <br/>
  STS[Security Token Service]
  
- Verify IAM permissions (need EC2, EKS, VPC, IAM, CloudFormation)
- Check AWS service limits (VPC, EIP limits)

#### 2. Pods stuck in Pending

**Symptoms**: Pods don't schedule to nodes

**Debug steps**:
```bash
kubectl get pods -n dev
kubectl describe pod <pod-name> -n dev
```

**Common causes**:
- Insufficient resources (check resource quotas)
- Node selector/affinity not matching
- Volume provisioning issues

#### 3. RBAC permission denied

**Symptoms**: "User cannot create deployments in namespace"

**Debug steps**:
```bash
kubectl auth can-i create deployments -n dev
kubectl get roles -n dev
kubectl describe role <role-name> -n dev
```

#### 4. High costs

**Solutions**:
- Use smaller instance types (t3.micro can work for demos)
- Reduce node count to 1 (loses HA)
- Delete cluster immediately after use
- Use spot instances (add to cluster config)

## Interview Talking Points

### Why This Architecture?

> "I designed this as a cost-effective learning environment that demonstrates production-ready patterns. The multi-namespace approach simulates multi-environment deployments while keeping infrastructure costs low. In a real production environment, I'd likely isolate production into its own cluster for stronger security boundaries and blast radius containment."

### RBAC Philosophy

> "I implemented a graduated permission model that reflects real-world practices. Dev has full access for rapid iteration, QA is read-only to prevent test environment drift, and production has deploy-only permissions to prevent accidental deletions. This demonstrates the principle of least privilege while enabling effective workflows."

### Resource Management

> "Resource quotas and limit ranges are critical for cluster stability. Without them, a single misbehaving application could consume all cluster resources, causing a cascading failure. These configurations ensure fair resource distribution and enable better capacity planning."

### High Availability

> "The cluster spans two availability zones to withstand datacenter failures. Pod anti-affinity rules distribute replicas across nodes, and health probes enable automatic recovery from application failures. Combined with Kubernetes' self-healing capabilities, this provides a highly available platform."

### Observability

> "I enabled CloudWatch logging for the control plane to capture audit trails and troubleshooting data. In a complete solution, I'd add Prometheus for metrics, Grafana for visualization, and implement distributed tracing with Jaeger or AWS X-Ray. These form the three pillars of observability: metrics, logs, and traces."

### Cost Optimization

> "I optimized costs by using t3.small instances, a single NAT gateway, and reduced CloudWatch log retention. For production, I'd evaluate using Karpenter for intelligent autoscaling, reserved instances for predictable workloads, and spot instances for fault-tolerant workloads. The key is balancing reliability requirements with cost constraints."

### SRE Principles

> "This project demonstrates several SRE principles: \n
> 1) **Automation**: Infrastructure as code with versioned configurations \n
> 2) **Reliability**: Multi-AZ deployment, health checks, resource limits \n
> 3) **Observability**: Logging infrastructure for troubleshooting \n
> 4) **Efficiency**: Cost optimization without sacrificing learning value \n
> 5) **Simplicity**: Clear structure and documentation"

## Next Steps

After mastering this foundation, consider:

1. **Add Prometheus & Grafana** for metrics and dashboards
2. **Implement GitOps** with ArgoCD or Flux
3. **Add Ingress controller** (NGINX or AWS ALB)
4. **Implement autoscaling** (HPA, VPA, Cluster Autoscaler)
5. **Add service mesh** (Istio or Linkerd) for advanced networking
6. **Implement CI/CD pipeline** with Jenkins/GitHub Actions
7. **Add monitoring/alerting** for SLO tracking

---

*For questions or clarifications, refer to the main README or open an issue.*
