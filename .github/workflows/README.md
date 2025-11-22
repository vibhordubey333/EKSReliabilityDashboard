# GitHub Actions CI/CD Pipeline

## Overview

This directory contains the GitHub Actions workflows for automated building, testing, and deployment of the SRE Demo Service.

## Workflows

### [pipeline.yaml](pipeline.yaml)

Main CI/CD pipeline with progressive deployment across environments.

**Trigger:** Push to `main`, `develop`, or `Feature/*` branches

**Stages:**

1. **Build and Test**
   - Builds Go binary
   - Runs unit tests with coverage
   - Uploads coverage to Codecov

2. **Docker Build and Push**
   - Builds Docker image
   - Tags with Git SHA, branch name, and `latest`
   - Pushes to AWS ECR

3. **Deploy to Dev** (automatic)
   - Deploys to `dev` namespace
   - Waits for rollout completion

4. **Deploy to QA** (automatic after Dev)
   - Deploys to `qa` namespace
   - Only runs if Dev deployment succeeds

5. **Deploy to Prod** (manual approval required)
   - Requires manual approval via GitHub UI
   - Only runs on `main` branch
   - Deploys to `prod` namespace

---

## Configuration

### Required GitHub Secrets

Configure these in: **Settings > Secrets and variables > Actions > New repository secret**

| Secret Name | Description | Where to Get |
|-------------|-------------|--------------|
| `AWS_ACCESS_KEY_ID` | AWS access key for ECR and EKS access | AWS IAM Console → Create access key |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key | AWS IAM Console → Create access key (shown only once!) |

**IAM Permissions Required:**
- `AmazonEC2ContainerRegistryFullAccess` (for pushing Docker images)
- `AmazonEKSClusterPolicy` (for deploying to EKS)

### Environment Variables (Pre-configured in Workflow)

These are already set in `pipeline.yaml` and match your cluster configuration:

| Variable | Value | Where Defined | Notes |
|----------|-------|---------------|-------|
| `AWS_REGION` | `us-east-1` | `pipeline.yaml` env section | Matches `cluster-config.yaml` |
| `EKS_CLUSTER_NAME` | `eks-reliability-demo` | `pipeline.yaml` env section | Matches `scripts/setup-cluster.sh` |
| `ECR_REPOSITORY` | `sre-demo-service` | `pipeline.yaml` env section | Matches `scripts/build-and-push.sh` |
| `GO_VERSION` | `1.21` | `pipeline.yaml` env section | Go language version |

**To change these values:** Edit the `env:` section in `.github/workflows/pipeline.yaml`

### Environment Protection Rules

Configure these in: **Settings > Environments**

#### Required: Production Environment

1. Click **New environment**
2. Name: `production`
3. Enable **Required reviewers**
4. Add GitHub usernames who can approve deployments
5. Optional settings:
   - **Prevent self-review**: Recommended for team environments
   - **Wait timer**: Add delay before deployment can proceed
   - **Deployment branches**: Restrict to `main` branch only
6. Click **Save protection rules**

#### Optional: Development and QA Environments

Create `development` and `qa` environments for tracking purposes (no protection rules needed).

---

## Usage

### Automatic Deployment

**Develop Branch:**
```bash
git checkout develop
git add .
git commit -m "feat: add new feature"
git push origin develop
```

Pipeline automatically:
- Builds and tests
- Pushes Docker image
- Deploys to Dev
- Deploys to QA

**Main Branch (Production):**
```bash
git checkout main
git merge develop
git push origin main
```

Pipeline:
- Builds and tests
- Pushes Docker image
- Deploys to Dev
- Deploys to QA
- **Waits for manual approval**
- After approval: Deploys to Prod

### Manual Approval Process

1. Go to **Actions** tab in GitHub
2. Click on the running workflow
3. Click **Review deployments**
4. Select `production` environment
5. Add comment (optional)
6. Click **Approve and deploy**

---

## Monitoring Pipeline

### View Workflow Runs

1. Go to **Actions** tab
2. Click on a workflow run to see details
3. Click on a job to see logs

### View Deployment Status

```bash
# Check deployment status
kubectl get deployments -n dev
kubectl get deployments -n qa
kubectl get deployments -n prod

# View rollout history
kubectl rollout history deployment/sre-demo-service -n dev
```

---

## Rollback

### Via Kubectl

```bash
# Rollback to previous version
kubectl rollout undo deployment/sre-demo-service -n prod

# Rollback to specific revision
kubectl rollout undo deployment/sre-demo-service -n prod --to-revision=2

# View rollout status
kubectl rollout status deployment/sre-demo-service -n prod
```

### Via GitHub Actions

1. Find the previous successful deployment
2. Click **Re-run jobs**
3. Approve production deployment

---

## Troubleshooting

### Build Fails

**Check:**
- Go version compatibility
- Test failures
- Linting errors

**Fix:** Review logs and fix code issues

### Docker Push Fails

**Check:**
- AWS credentials configured correctly
- ECR repository exists
- IAM permissions for ECR push

**Fix:**
```bash
# Verify ECR repository
aws ecr describe-repositories --repository-names sre-demo-service

# Test AWS credentials
aws sts get-caller-identity
```

### Deployment Fails

**Check:**
- EKS cluster running
- kubectl configuration
- Image exists in ECR
- Deployment manifests valid

**Fix:**
```bash
# Verify cluster access
kubectl get nodes

# Check deployment
kubectl describe deployment sre-demo-service -n dev

# Check pods
kubectl get pods -n dev -l app=sre-demo-service
kubectl logs -n dev -l app=sre-demo-service --tail=50
```

### Approval Not Working

**Check:**
- Production environment created
- Required reviewers configured
- Correct user has approval permissions

**Fix:** Go to Settings > Environments > production and verify configuration

---

## Local Testing

### Test Build and Tests Locally

```bash
cd app
go build -v ./...
go test -v ./...
```

### Test Docker Build Locally

```bash
docker build -t sre-demo-service:local -f app/Dockerfile ./app
docker run -p 8080:8080 sre-demo-service:local
```

### Test Deployment Locally

```bash
# Update image
kubectl set image deployment/sre-demo-service \
  sre-demo-service=<your-image> \
  -n dev

# Watch rollout
kubectl rollout status deployment/sre-demo-service -n dev
```

---

## Best Practices

1. **Always test on develop first** before merging to main
2. **Use feature branches** for new features (Feature/*)
3. **Write meaningful commit messages** (they appear in GitHub Actions)
4. **Review deployment logs** before approving production
5. **Have a rollback plan** for production deployments
6. **Monitor after deployment** using Grafana and Kibana

---

## Future Enhancements

- Add integration tests
- Add smoke tests after deployment
- Implement blue/green deployments
- Add Slack/email notifications
- Implement canary deployments
- Add performance testing stage
