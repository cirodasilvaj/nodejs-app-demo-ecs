# bkstg-made-nodejs-demo22

Node.js 20 containerized microservice deployed to AWS ECS Fargate with dual-environment architecture (`dev` and `stage`), automated CI/CD via GitHub Actions, ESLint code analysis, Jest unit testing, and modular Terraform infrastructure.

---

## 🏛 Architecture Overview

```
                      +---------------------------------------+
                      |           GitHub Actions CI/CD        |
                      +-------------------+-------------------+
                                          |
                        [Lint: ESLint] & [Test: Jest]
                                          |
                             [Docker Build & ECR Push]
                                          |
                +-------------------------+-------------------------+
                |                                                   |
       (develop / main)                                          (main)
                v                                                   v
   +-------------------------+                         +-------------------------+
   |   Dev ECS Environment   |                         |  Stage ECS Environment  |
   | Cluster: ...-dev        |                         | Cluster: ...-stage      |
   | ALB: ...-dev-alb:80     |                         | ALB: ...-stage-alb:80   |
   | Fargate Task (:8080)    |                         | Fargate Task (:8080)    |
   | LogGroup: /ecs/...-dev  |                         | LogGroup: /ecs/...-stage|
   +-------------------------+                         +-------------------------+
```

### Components Provisioned
- **Networking**: Dedicated VPC (`10.0.0.0/16`), Internet Gateway, 2 Multi-AZ Public Subnets, Route Tables, and separate Security Groups for Dev and Stage.
- **Container Registry**: Amazon ECR repository with automated tag mutability and image lifecycle policies (retains 15 images).
- **ECS Clusters (Fargate)**:
  - `bkstg-made-nodejs-demo22-dev`
  - `bkstg-made-nodejs-demo22-stage`
- **Application Load Balancers (ALB)**:
  - Dev ALB with listener on port 80 and target group pointing to `/healthz` on container port `8080`.
  - Stage ALB with listener on port 80 and target group pointing to `/healthz` on container port `8080`.
- **Observability**: CloudWatch Log Groups for both environments (`/ecs/bkstg-made-nodejs-demo22-dev` and `/ecs/bkstg-made-nodejs-demo22-stage`).
- **Security**: Granular IAM Task Execution Role and Task Role following least-privilege principles.

---

## 🚀 Local Development & Testing

### 1. Install Dependencies
```bash
npm install
```

### 2. Linting (ESLint)
```bash
npm run lint
```

### 3. Unit Testing (Jest)
```bash
npm test
```

### 4. Run Locally
```bash
npm start
```
Microservice will listen on `http://localhost:8080`. Available endpoints:
- `GET /` - Root endpoint (HTML & JSON support)
- `GET /api/info` - Host & system metadata payload
- `GET /healthz` - Health check endpoint (used by ALB)
- `GET /metrics` - Prometheus metrics

---

## ☁️ Terraform Infrastructure Deployment

The Terraform definitions live in [`terraform/`](file:///home/ciro/Documents/A_desenvolvimento/nodejs-app-demo/bkstg-made-nodejs-demo22/terraform).

### 1. Initialize & Validate
```bash
cd terraform
terraform init
terraform validate
```

### 2. Plan Infrastructure
Export your AWS credentials or configure `~/.aws/credentials`:
```bash
export AWS_ACCESS_KEY_ID="<YOUR_KEY_ID>"
export AWS_SECRET_ACCESS_KEY="<YOUR_SECRET_KEY>"
export AWS_DEFAULT_REGION="us-east-1"

terraform plan
```

### 3. Apply Infrastructure
```bash
terraform apply -auto-approve
```

### 4. Terraform Outputs
Upon apply completion, Terraform provides:
- `dev_alb_url`: Direct URL to reach the Dev microservice.
- `stage_alb_url`: Direct URL to reach the Stage microservice.
- `ecr_repository_url`: ECR registry endpoint for container pushes.
- `dev_ecs_cluster_name` & `stage_ecs_cluster_name`: ECS cluster names.

---

## 🔄 GitHub Actions CI/CD Pipeline

The automated workflow is located at [`.github/workflows/ci-cd.yml`](file:///home/ciro/Documents/A_desenvolvimento/nodejs-app-demo/bkstg-made-nodejs-demo22/.github/workflows/ci-cd.yml).

### Pipeline Stages
1. **`test-and-lint`**: Checks out repository, installs dependencies, executes `npm run lint` (ESLint) and `npm test` (Jest with coverage).
2. **`terraform-validate`**: Verifies Terraform formatting, syntax, and provider declarations.
3. **`build-and-push`**: Logs into Amazon ECR, builds Docker image, tags with commit SHA, branch name, and `latest`, and pushes to ECR.
4. **`deploy-dev`**: Updates task definition and rolls out deployment to the Dev ECS cluster (`bkstg-made-nodejs-demo22-dev`).
5. **`deploy-stage`**: Updates task definition and rolls out deployment to the Stage ECS cluster (`bkstg-made-nodejs-demo22-stage`). Triggered on `main` branch merges.

### Required GitHub Secrets
Under **GitHub Repository Settings > Secrets and variables > Actions**, configure:
| Secret Name | Description | Example / Note |
|---|---|---|
| `AWS_ACCESS_KEY_ID` | AWS IAM Access Key | Configured in GitHub Secrets |
| `AWS_SECRET_ACCESS_KEY` | AWS IAM Secret Access Key | Configured in GitHub Secrets |
| `AWS_REGION` *(optional)* | AWS Region | Defaults to `us-east-1` in workflow |
