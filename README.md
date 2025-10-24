
## **Step 1: Launch an EC2 instance**

- Go to **AWS Console → EC2 → Launch Instance**.
    
- Choose an Ubuntu AMI (e.g., 22.04 LTS).
    
- Select an instance type (e.g., `t2.micro`).
    
- Assign a **security group** that allows:
    
    - SSH from your IP
        
    - Incoming traffic on the app port (8080) from your ALB later
        
- Launch the instance and note its public IP.
    

---

## **Step 2: Run update commands**

SSH into the instance and update packages:

```
sudo apt-get update
sudo apt-get install docker.io -y
sudo apt update
sudo apt install ca-certificates curl gnupg -y
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install docker-compose-plugin -y
sudo apt update && sudo apt install ruby wget -y
cd /home/ubuntu
wget https://aws-codedeploy-us-east-1.s3.amazonaws.com/latest/install
chmod +x ./install
sudo ./install auto
sudo systemctl start codedeploy-agent
sudo systemctl enable codedeploy-agent
sudo systemctl status codedeploy-agent

```




- This ensures the system is up-to-date and Docker is installed and running.
    

---

## **Step 3: Clone the GitHub repository**

```
git clone https://github.com/ItsAlvii/autoscaing-project.git
cd autoscaing-project
```

- This pulls your backend project onto the EC2 instance.


## Step 4: Prepare the IAM Roles(Instance Role)

### 1. EC2CodeDeployRole

1. Go To AWS > **IAM** > **Roles**

2. Create IAM Role: `EC2CodeDeployRole`

3. Attach managed policy: `AWSCodeDeployRole` (or custom policy allowing `codedeploy:*`, S3 access, CloudWatch logs)
 
4. Attach this role to your **launch template** used by the ASG (We will do this in the next step dont worry)

### 2. AWSCodeDeployRole

1. Go To AWS > **IAM** > **Roles**

2. Create IAM Role: AWSCodeDeployRole

3. Attach this inline policy to it
   
```

{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "autoscaling:*",
        "application-autoscaling:*",
        "cloudwatch:DescribeAlarms",
        "cloudwatch:GetMetricStatistics",
        "cloudwatch:PutMetricAlarm",
        "cloudwatch:DeleteAlarms",
        "ec2:DescribeLaunchTemplateVersions",
        "ec2:DescribeInstances",
        "ec2:DescribeImages",
        "ec2:DescribeSubnets",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeKeyPairs",
        "ec2:DescribeAvailabilityZones",
        "ec2:DescribeAccountAttributes",
        "ec2:DescribeInstanceTypes",
        "ec2:DescribeVpcClassicLink",
        "ec2:DescribeClassicLinkInstances",
        "elasticloadbalancing:DescribeLoadBalancers",
        "elasticloadbalancing:DescribeLoadBalancerAttributes",
        "elasticloadbalancing:DescribeTargetGroups",
        "elasticloadbalancing:DescribeTargetHealth",
        "elasticloadbalancing:RegisterTargets",
        "elasticloadbalancing:DeregisterTargets",
        "sns:ListTopics",
        "sns:Publish",
        "iam:ListRoles",
        "iam:PassRole"
      ],
      "Resource": "*"
    }
  ]
}


```

## **Step 5: Create an AMI from the instance (Console)**

1. In **AWS Console → EC2 → Instances**, select your instance.
    
2. Click **Actions → Image → Create Image**.
    
3. Name it: `project-autoscale-ami-YYYYMMDD`.
    
4. Attach IAM Role you created for EC2 Earlier (EC2CodeDeployRole)


Click **Create Image** and wait until the AMI status is `Available`.

**Why:** This AMI will be used in the Launch Template so new instances start pre-configured with Docker and your image.


## **Step 6: Create a Launch Template and attach the AMI and Role**

1. Go to **EC2 → Launch Templates → Create Launch Template**.
    
2. Name it: `project-autoscale-template`.
    
3. Select the AMI created in Step 7.
    
4. Set the **instance type** (e.g., `t2.micro`).
    
5. Attach **security groups** (allow SSH for debugging, app traffic from ALB).
    
6. Assign **IAM role** `EC2CodeDeployRole`
    
7. Optionally, paste **user-data** to pull the Docker image on boot:
    

```
#!/bin/bash
cd /home/ubuntu/autoscaing-project
sudo docker stop app || true
sudo docker rm app || true
sudo docker run -d -p 8080:8080 --name app haideralvii/project-autoscale

```

## **Step 7: Create a Target Group**

1. Go to **EC2 → Target Groups → Create Target Group**.
    
2. Target type: **Instance**.
    
3. Protocol: **HTTP**, Port: `8080` (your app port).
    
4. VPC: select your app’s VPC.
    
5. Health check: path `/` or `/health`.
    
6. Click **Create**.
    

- **Why:** ALB will forward traffic to this TG, and ASG instances will register here.
    

---

## **Step 8: Create a Load Balancer**

1. Go to **EC2 → Load Balancers → Create Load Balancer → Application Load Balancer**.
    
2. Name: `project-autoscale-alb`.
    
3. Scheme: **Internet-facing**.
    
4. Listeners: HTTP port 80.
    
5. Select **Availability Zones**.
    
6. Security group: attach ALB SG (allows 80 from anywhere).
    
7. Routing: attach the **Target Group** created in Step 9.
    
8. Click **Create**.
    

- **Why:** ALB balances incoming traffic and routes it to healthy instances in the TG.
    

---

## **Step 9: Create an Auto Scaling Group and attach everything**

1. Go to **EC2 → Auto Scaling Groups → Create Auto Scaling Group**.
    
2. Name: `project-autoscale-asg`.
    
3. Select the **Launch Template** created in Step 8.
    
4. VPC and subnets: choose multiple AZs for HA.
    
5. Attach to the **ALB / Target Group** from Step 9 & 10.
    
6. Set min/desired/max instances (e.g., 1/1/3).
    
7. Configure scaling policies if needed.
    
8. Click **Create ASG**.
   


# CODEDEPLOY SETUP & CD PIPELINE

Now we set up CodeDeploy and GitHub Actions to automate deploys.

---

## 10) Create CodeDeploy Application

1. AWS Console → **CodeDeploy** → **Applications** → **Create application**.
    
2. Name: `project-autoscale-app`.
    
3. Compute platform: **EC2/On-Premises**.
    
4. Create.
    

---

## 11) Create CodeDeploy Deployment Group

1. In your CodeDeploy Application → **Create deployment group**.
    
2. Name: `project-autoscale-dg`.
    
3. Service role: select `CodeDeployServiceRole` (created in step 4.2).
    
4. Deployment type: **Blue/Green for for EC2).
5. Environment configuration: 
   
   Automatically Copy Amazon Ec2 AutoScaling
   choose **Auto Scaling groups** or choose **EC2 tags**. To attach the ASG:
    
    - Under “Environment configuration”, choose **Auto Scaling groups**, click **Add**, and select your ASG.
        
6. Load balancer: choose **Application Load Balancer** and provide the target group (this allows CodeDeploy to manage instance registration/deregistration during deployments).
    
7. Create the Deployment Group.
    

**Note:** CodeDeploy must be able to interact with Auto Scaling to coordinate rollbacks — that's why the service role `AWSCodeDeployRole` is required. [AWS Documentation](https://docs.aws.amazon.com/aws-managed-policy/latest/reference/AWSCodeDeployRole.html?utm_source=chatgpt.com)

---

## 12) Prepare your app revision (appspec + scripts)

Your repo should contain an `appspec.yml` at the root, and a `/scripts` folder with the lifecycle scripts. Below is a recommended example for Docker container deployments to EC2 via CodeDeploy.

### `appspec.yml` (example)

```
version: 0.0
os: linux

files:
  - source: /
    destination: /home/ubuntu/autoscaling-project

hooks:
  ApplicationStop:
    - location: scripts/stop_container.sh
      timeout: 60
      runas: root
  BeforeInstall:
    - location: scripts/cleanup.sh
      timeout: 60
      runas: root
  ApplicationStart:
    - location: scripts/start_container.sh
      timeout: 300
      runas: root
```

(see AWS AppSpec + hooks reference for full details). [AWS Documentation+1](https://docs.aws.amazon.com/codedeploy/latest/userguide/reference-appspec-file-example.html?utm_source=chatgpt.com)

### scripts/stop_container.sh

```
#!/bin/bash
set -e

# Stop and remove container
docker stop project-autoscale || true
docker rm project-autoscale || true
```

### scripts/start_container.sh

```
#!/bin/bash
set -e

# Load deployment environment variables (for SHA tag)
if [ -f /home/ubuntu/autoscaling-project/scripts/deploy_env.sh ]; then
    source /home/ubuntu/autoscaling-project/scripts/deploy_env.sh
fi

DOCKERHUB_USERNAME="your_username"
IMAGE_NAME="${DOCKERHUB_USERNAME}/your_project_name"
IMAGE_TAG="${DEPLOY_IMAGE_TAG:-latest}"

# Ensure Docker is running
systemctl start docker

# Stop and remove old container if exists
docker rm -f project-autoscale || true

# Pull and run new container
docker pull "${IMAGE_NAME}:${IMAGE_TAG}"
# docker run -d --name project-autoscale -p 8080:8080 --restart=always "${IMAGE_NAME}:${IMAGE_TAG}"
```

### scripts/cleanup.sh

```
#!/bin/bash
set -e

# Remove unused Docker resources
docker system prune -f || true
```

**Permissions:** `chmod +x scripts/*.sh` and commit them in your repo.

**AppSpec notes:** the `hooks` map lifecycle events to scripts. More details in AWS docs. [AWS Documentation](https://docs.aws.amazon.com/codedeploy/latest/userguide/reference-appspec-file-structure-hooks.html?utm_source=chatgpt.com)

---

## 13) GitHub Actions workflow (CI → build image → push → package revision → upload to S3 → create CodeDeploy deployment)

Place `.github/workflows/deploy.yml` in your repo:

```
name: Build, Push, and Deploy via AutoScaling

on:
  push:
    branches:
      - main

jobs:
  build-push-deploy:
    runs-on: ubuntu-latest

    steps:
      # 1️⃣ Checkout repository
      - name: Checkout repository
        uses: actions/checkout@v4

      # 2️⃣ Set up Docker Buildx
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      # 3️⃣ Log in to Docker Hub
      - name: Log in to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}

      # 4️⃣ Build and push Docker image
      - name: Build and push Docker image
        env:
          IMAGE_NAME: ${{ secrets.DOCKERHUB_USERNAME }}/project-autoscale
        run: |
          IMAGE_TAG=${{ github.sha }}
          echo "Building Docker image: $IMAGE_NAME:$IMAGE_TAG"
          docker build -t $IMAGE_NAME:$IMAGE_TAG .
          docker push $IMAGE_NAME:$IMAGE_TAG
          docker tag $IMAGE_NAME:$IMAGE_TAG $IMAGE_NAME:latest
          docker push $IMAGE_NAME:latest
          echo "DEPLOY_IMAGE_TAG=$IMAGE_TAG" > deploy_env.sh

      # 5️⃣ Configure AWS credentials (directly)
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1

      # 6️⃣ Trigger CodeDeploy deployment
      - name: Trigger CodeDeploy deployment
        run: |
          echo "Triggering CodeDeploy deployment..."
          aws deploy create-deployment \
            --application-name autoscale-app \
            --deployment-group-name project-autoscale-dg-new \
            --github-location repository=${{ github.repository }},commitId=${{ github.sha }}

      # 7️⃣ Log deployment
      - name: Log deployment
        run: echo "✅ Deployment triggered — ASG instances will pull the latest Docker image on startup."

```

**Required GitHub Secrets:**

- `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` (Docker Hub access token),
    
- `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`,
    
- `S3_BUCKET` (existing S3 bucket for CodeDeploy revisions; create and set proper bucket policy),
    
- `CODEDEPLOY_APP_NAME` (e.g., `project-autoscale-app`),
    
- `CODEDEPLOY_DEPLOYMENT_GROUP` (e.g., `project-autoscale-dg`).
    

**Optional (better security):** Use GitHub OIDC to avoid long-lived AWS keys (see AWS blog on GitHub Actions integration). [Amazon Web Services, Inc.](https://aws.amazon.com/blogs/devops/integrating-with-github-actions-ci-cd-pipeline-to-deploy-a-web-app-to-amazon-ec2/?utm_source=chatgpt.com)

**Notes about S3 + IAM:** Ensure the CodeDeploy service role and the AWS credentials used by Actions can upload to the S3 bucket and that the `EC2CodeDeployRole` instance profile can read from the S3 bucket (S3 `GetObject` on the specific prefix).

---

## 14) Final deploy (triggering)

1. Push changes to `main` → the GitHub Actions workflow builds the image, pushes to Docker Hub, uploads the revision to S3, and issues the `aws deploy create-deployment` command.
    
2. CodeDeploy will run the AppSpec hooks on the targeted instances (ASG → instances), invoking `stop_container.sh`, `cleanup.sh`, and `start_container.sh` in order.
    
3. Verify in CodeDeploy console: see deployment status, logs, and instance events.
    

**Troubleshooting tips:**

- If hooks do not run, check `/opt/codedeploy-agent/deployment-root/deployment-logs` and the CodeDeploy agent logs on the instance.
    
- Ensure your `appspec.yml` paths match the zip contents exactly.
    
- If instance health checks fail in ALB, check container logs and ensure port mapping (8080) is correct.
    

---

## Helpful checks & commands

On an EC2 instance (for debugging):

```
`# Check CodeDeploy agent 
sudo systemctl status codedeploy-agent sudo tail -n 200 /var/log/aws/codedeploy-agent/codedeploy-agent.log  
# check latest deployment logs on instance (deployment root) 
ls -lah /opt/codedeploy-agent/deployment-root`
```

---

## Cleanup plan (if you want to destroy resources after tests)

- Delete the Auto Scaling Group (scale to zero first), delete Launch Template, delete ALB, Target Group, delete AMI, delete snapshots, delete S3 revision bucket (careful), delete CodeDeploy Application & Deployment Group, delete IAM roles (be cautious about used roles).
    

---

## Quick checklist (one-page)

1. Launch EC2 instance (build host) → install Docker + CodeDeploy agent.
    
2. Clone repo, build Docker image, test locally.
    
3. Push image to Docker Hub.
    
4. Create `EC2CodeDeployRole` (attach `AmazonEC2RoleforAWSCodeDeploy` + `AmazonSSMManagedInstanceCore`). [AWS Documentation+1](https://docs.aws.amazon.com/aws-managed-policy/latest/reference/AmazonEC2RoleforAWSCodeDeploy.html?utm_source=chatgpt.com)
    
5. Create `CodeDeployServiceRole` (attach `AWSCodeDeployRole`). [AWS Documentation](https://docs.aws.amazon.com/aws-managed-policy/latest/reference/AWSCodeDeployRole.html?utm_source=chatgpt.com)
    
6. Create AMI from build host.
    
7. Create Launch Template (use AMI + instance profile). [AWS Documentation](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/create-launch-template.html?utm_source=chatgpt.com)
    
8. Create Target Group → ALB. [AWS Documentation](https://docs.aws.amazon.com/autoscaling/ec2/userguide/attach-load-balancer-asg.html?utm_source=chatgpt.com)
    
9. Create Auto Scaling Group using Launch Template & attach TG. [AWS Documentation](https://docs.aws.amazon.com/autoscaling/ec2/userguide/tutorial-ec2-auto-scaling-load-balancer.html?utm_source=chatgpt.com)
    
10. Create CodeDeploy App & Deployment Group (attach ASG + ALB).
    
11. Add `appspec.yml` + `scripts/*.sh`. (AppSpec hooks docs: see AWS docs.) [AWS Documentation+1](https://docs.aws.amazon.com/codedeploy/latest/userguide/reference-appspec-file-example.html?utm_source=chatgpt.com)
    
12. Create GitHub Actions workflow: build, push, zip, upload to S3, `aws deploy create-deployment`. (Consider OIDC instead of long-lived keys.) [Amazon Web Services, Inc.](https://aws.amazon.com/blogs/devops/integrating-with-github-actions-ci-cd-pipeline-to-deploy-a-web-app-to-amazon-ec2/?utm_source=chatgpt.com)
    

---

## References (official, for deeper troubleshooting)

- AppSpec examples & format (hooks + structure). [AWS Documentation+1](https://docs.aws.amazon.com/codedeploy/latest/userguide/reference-appspec-file-example.html?utm_source=chatgpt.com)
    
- AmazonEC2RoleforAWSCodeDeploy (what to attach to instances). [AWS Documentation](https://docs.aws.amazon.com/aws-managed-policy/latest/reference/AmazonEC2RoleforAWSCodeDeploy.html?utm_source=chatgpt.com)
    
- AWSCodeDeployRole (service role for CodeDeploy). [AWS Documentation](https://docs.aws.amazon.com/aws-managed-policy/latest/reference/AWSCodeDeployRole.html?utm_source=chatgpt.com)
    
- Launch template creation guide. [AWS Documentation](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/create-launch-template.html?utm_source=chatgpt.com)
    
- GitHub Actions → CodeDeploy integration patterns (AWS blog). [Amazon Web Services, Inc.](https://aws.amazon.com/blogs/devops/integrating-with-github-actions-ci-cd-pipeline-to-deploy-a-web-app-to-amazon-ec2/?utm_source=chatgpt.com)
    

