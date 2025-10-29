
# 🚀 **End-to-End CI/CD Auto Scaling Deployment on AWS (EC2 + CodeDeploy + GitHub Actions)**

This guide demonstrates how to deploy a Dockerized backend application on AWS using **EC2 Auto Scaling**, **Application Load Balancer (ALB)**, **CodeDeploy**, and **GitHub Actions** for continuous integration and deployment.

It follows a **real-world, production-ready pattern** where:

- A base EC2 instance is prepared with Docker and CodeDeploy agent.
    
- The image is **built and run** directly on EC2 (ensuring it works).
    
- An **AMI is created** from that preconfigured instance.
    
- CodeDeploy + GitHub Actions handle future automated updates via **S3-based revision deployments**.
    

> ⚙️ _Replace placeholders like `your-username`, `your-s3-bucket-name`, etc. with your actual values._

---

## **Step 1: Launch an EC2 Instance**

1. Go to **AWS Console → EC2 → Launch Instance**
    
2. Choose an Ubuntu AMI (e.g., **Ubuntu 22.04 LTS**)
    
3. Instance type: `t2.micro` (or higher if needed)
    
4. Configure a **security group** that allows:
    
    - SSH (port 22) from your IP
        
    - HTTP (port 8080) for app traffic
        
5. Launch the instance and note its **public IP address**
    

---

## **Step 2: Install Dependencies and CodeDeploy Agent**

SSH into the instance:

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

---

## **Step 3: Clone the Repository**

`git clone https://github.com/your-username/autoscaing.git cd autoscaing`

> 🔸 Note: Replace `autoscaing` with whatever name appears when you clone your repository.

---

## **Step 4: Prepare IAM Roles**

### 1. **EC2 Instance Role (e.g., `EC2CodeDeployRole`)**

- Go to **IAM → Roles → Create role**
    
- Trusted entity: **EC2**
    
- Attach policies:
    
    - `AmazonEC2RoleforAWSCodeDeploy`
        
    - `AmazonSSMManagedInstanceCore`
        
- Name it `EC2CodeDeployRole`
    
Attach an inline policy to allow it to use S3

```
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "CodeDeployS3Access",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::<your-s3-bucket-name>",
        "arn:aws:s3:::<your-s3-bucket-name>/*"
      ]
    }
  ]
}

```
### 2. **CodeDeploy Service Role (e.g., `CodeDeployServiceRole`)**

- Go to **IAM → Roles → Create role**
    
- Trusted entity: **CodeDeploy**
    
- Attach managed policy: `AWSCodeDeployRole`
    
- Add the following **inline policy**:
    

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
        "iam:PassRole",
        "codedeploy:*",
        "s3:Get*",
        "s3:List*",
        "logs:*"
      ],
      "Resource": "*"
    }
  ]
}
```

---

## **Step 5: Build and Run the Docker Image (on EC2)**

From inside `/home/ubuntu/autoscaing`:

`docker build -t your-username/your-project-name:latest . docker run -d -p 8080:8080 your-username/your-project-name`

> ✅ **Tip:** Make sure the container runs successfully before creating an AMI.  
> This ensures your base AMI always launches with a working environment.

---

## **Step 6: Configure `systemd` for Auto-Start**

Create a systemd service so your container auto-starts on boot:

`sudo nano /etc/systemd/system/autoscaing.service`

Paste:

```
[Unit]
Description=Autoscaling App Container
After=docker.service
Requires=docker.service

[Service]
ExecStart=/usr/bin/docker run --rm -d -p 8080:8080 --name autoscaing your-username/your-project-name:latest
ExecStop=/usr/bin/docker stop autoscaing
Restart=always

[Install]
WantedBy=multi-user.target
```

Then enable and start it:

`sudo systemctl daemon-reload sudo systemctl enable autoscaing sudo systemctl start autoscaing sudo systemctl status autoscaing`

---

## **Step 7: Create an AMI from the Configured Instance**

1. In **AWS Console → EC2 → Instances**
    
2. Select your instance → **Actions → Image → Create Image**
    
3. Name it: `autoscaing-ami-YYYYMMDD`
    
4. Attach the `EC2CodeDeployRole` IAM role
    
5. Wait until the AMI status becomes **Available**
    

> 🎯 _Why:_ This AMI ensures all future Auto Scaling instances come preconfigured with Docker, CodeDeploy, and your running app.

---

## **Step 8: Create Launch Template**

1. Go to **EC2 → Launch Templates → Create Template**
    
2. Name: `autoscaing-template`
    
3. Select your AMI
    
4. Instance type: `t2.micro`
    
5. Security groups: same as before
    
6. Attach IAM Role: `EC2CodeDeployRole`
    
7. No user data (we’re using `systemd`)
    

---

## **Step 9: Create Target Group and Load Balancer**

### **Target Group**

- **Type:** Instance
    
- **Protocol:** HTTP
    
- **Port:** 8080
    
- **Health check path:** `/`
    
- Click **Create**
    

### **Load Balancer**

- **Type:** Application Load Balancer
    
- Scheme: Internet-facing
    
- Listener: Port 80 → Forward to Target Group
    
- Attach ALB Security Group
    
- Click **Create**
    

---

## **Step 10: Create Auto Scaling Group**

1. Go to **EC2 → Auto Scaling Groups → Create**
    
2. Name: `autoscaing-asg`
    
3. Use the Launch Template from Step 8
    
4. Select VPC/Subnets
    
5. Attach the Target Group from Step 9
    
6. Set min/desired/max capacity (e.g., 1/1/3)
    
7. Create the ASG
    

---

## **Step 11: Create S3 Bucket for CodeDeploy Revisions**

1. Go to **S3 → Create bucket**
    
2. Name it `your-s3-bucket-name`
    
3. Block public access (keep private)
    
4. CodeDeploy and GitHub Actions will upload deployment revisions here
    

---

## **Step 12: Create CodeDeploy Application and Deployment Group**

### **Application**

- **Name:** `autoscaing-app`
    
- **Compute platform:** EC2/On-premises
    

### **Deployment Group**

- **Name:** `autoscaing-dg`
    
- **Service Role:** `CodeDeployServiceRole`
    
- **Environment configuration:** Auto Scaling group = `autoscaing-asg`
    
- **Load balancer:** select your ALB target group
    
- **Deployment type:** Blue/Green (recommended)
    

---

## **Step 13: AppSpec and Lifecycle Scripts**

In your repo root:

**`appspec.yml`**

```
version: 0.0
os: linux
files:
  - source: /
    destination: /home/ubuntu/autoscaing-project

hooks:
  BeforeInstall:
    - location: scripts/pre_cleanup.sh
      timeout: 60
      runas: root
  AfterInstall:
    - location: scripts/deploy_image.sh
      timeout: 300
      runas: root
```

deploy_image.sh

```
#!/bin/bash
set -e

cd /home/ubuntu/autoscaing-project

if [ -f scripts/deploy_env.sh ]; then
  source scripts/deploy_env.sh
else
  echo "⚠️ deploy_env.sh not found, using 'latest' tag."
  DEPLOY_IMAGE_TAG="latest"
fi

IMAGE="haideralvii/project-autoscale:${DEPLOY_IMAGE_TAG}"

echo "🚀 Deploying image: $IMAGE"

systemctl start docker || true
docker pull "$IMAGE"
docker rm -f project-autoscale || true
docker run -d --name project-autoscale -p 8080:8080 --restart=always "$IMAGE"

echo "✅ Deployment finished: $IMAGE"
```

pre_cleanup.sh

```
#!/bin/bash
set -e

echo "Running pre-cleanup before file copy..."

# Stop any running containers (optional)
sudo docker stop app || true
sudo docker rm app || true

# Delete old deployment directory to prevent file conflicts
sudo rm -rf /home/ubuntu/autoscaing-project/* || true

echo "Pre-cleanup complete."
```

Make them executable:

`chmod +x scripts/*.sh`

---

## **Step 14: GitHub Actions CI/CD Workflow**

Create `.github/workflows/deploy.yml`:

```
name: Build, Push, and Deploy

on:
  push:
    branches:
      - main

jobs:
  build-push-deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}

      - name: Build and Push Docker image
        run: |
          IMAGE_TAG=${GITHUB_SHA::7}
          docker build -t haideralvii/project-autoscale:$IMAGE_TAG -t haideralvii/project-autoscale:latest .
          docker push haideralvii/project-autoscale:$IMAGE_TAG
          docker push haideralvii/project-autoscale:latest
          echo "DEPLOY_IMAGE_TAG=$IMAGE_TAG" > scripts/deploy_env.sh

      - name: Zip deployment bundle
        run: |
          zip -r deploy.zip appspec.yml scripts/

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1

      - name: Upload to S3
        run: |
          aws s3 cp deploy.zip s3://project-autoscale-bucket2/deploy-${GITHUB_SHA::7}.zip --region us-east-1

      - name: Create CodeDeploy deployment
        run: |
          aws deploy create-deployment \
            --application-name autoscale-app \
            --deployment-group-name project-autoscale-dg-new \
            --s3-location bucket=project-autoscale-bucket2,key=deploy-${GITHUB_SHA::7}.zip,bundleType=zip \
            --region us-east-1 \
            --description "GitHub Actions Deploy - ${GITHUB_SHA::7}"
```

**Required GitHub Secrets:**

- `DOCKERHUB_USERNAME`
    
- `DOCKERHUB_TOKEN`
    
- `AWS_ACCESS_KEY_ID`
    
- `AWS_SECRET_ACCESS_KEY`
    
- `AWS_REGION`
    
- `S3_BUCKET` _(optional if hardcoded in script)_
    

---

## **Step 15: Trigger the Pipeline**

Every time you push to `main`, the workflow:

1. Builds and pushes a new Docker image
    
2. Packages the repo into a `.zip` file
    
3. Uploads it to S3
    
4. Triggers CodeDeploy → ASG → instance rollout
    

Monitor the deployment via:

- **CodeDeploy Console** (deployment status)
    
- **ALB DNS name** (test your app)
    
- **EC2 logs** (`/var/log/aws/codedeploy-agent/`)
    

---

## **Verification Checklist**

✅ Base EC2 image built and running  
✅ AMI created successfully  
✅ Launch Template uses correct AMI + IAM role  
✅ Auto Scaling + ALB working  
✅ CodeDeploy agent active  
✅ GitHub Actions deploys via S3 and triggers CodeDeploy

---

## **Cleanup (Optional)**

If you want to remove all resources after testing:

- Delete ASG, Launch Template, ALB, Target Group
    
- Delete AMI and snapshots
    
- Delete CodeDeploy app + deployment group
    
- Delete S3 bucket
    
- Delete IAM roles
    

---

## **References**

- [AWS CodeDeploy Documentation](https://docs.aws.amazon.com/codedeploy/)
    
- [EC2 Launch Templates](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/create-launch-template.html)
    
- [GitHub Actions + AWS CI/CD Blog](https://aws.amazon.com/blogs/devops/integrating-with-github-actions-ci-cd-pipeline-to-deploy-a-web-app-to-amazon-ec2/)
