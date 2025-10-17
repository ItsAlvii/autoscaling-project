# Quickstart Guide — Autoscaling Project from GitHub

This guide shows how to deploy your backend project (`haideralvii/project-autoscale`) on AWS using EC2, Docker, AMI, Launch Template, Target Group, ALB, and Auto Scaling Group.

---

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
```

- This ensures the system is up-to-date and Docker is installed and running.
    

---

## **Step 3: Clone the GitHub repository**

```
git clone https://github.com/ItsAlvii/autoscaing-project.git
cd autoscaing-project
```

- This pulls your backend project onto the EC2 instance.
    

---

## **Step 4: Build the Docker image**

```
docker build -t haideralvii/project-autoscale:latest .
```

- This creates a Docker image locally, tagged as `latest`.
    

---

## **Step 5: Push image to Docker Hub**

You’ll need a Docker Hub account to store your app image so the Launch Template and ASG instances can pull it later.

### 🧩 **1. Create a Docker Hub Repository**

1. Go to https://hub.docker.com.
    
2. Click **Repositories → Create Repository**.
    
3. Name it something like `project-autoscale`.
    
4. Set visibility to **Public** (or Private if you prefer).
    

---

### 🔑 **2. Create a Personal Access Token**

1. Click your **profile → Account Settings → Security → New Access Token**.
    
2. Give it a name (e.g., `ec2-deploy-token`).
    
3. Copy the token somewhere safe — you won’t see it again.
    

---

### 🚀 **3. Log in to Docker Hub on EC2**

```
docker login -u your_dockerhub_username
```

- Paste your access token when prompted for a password.
    

---

### 📦 **4. Tag and Push Your Image**

```
docker tag haideralvii/project-autoscale:latest your_dockerhub_username/project-autoscale:latest
docker push your_dockerhub_username/project-autoscale:latest
```

- Replace `your_dockerhub_username` with your own username.
    
- Verify the image appears in your Docker Hub repo.
    

---

## **Step 6: Run Docker Compose**

```
docker compose up -d --build
```

- Builds (if necessary) and starts the container in detached mode.
    
- Verify it’s running:
    
    `docker ps curl localhost:8080`
    

---

## **Step 7: Create an AMI from the instance (Console)**

1. In **AWS Console → EC2 → Instances**, select your instance.
    
2. Click **Actions → Image → Create Image**.
    
3. Name it: `project-autoscale-ami-YYYYMMDD`.
    
4. Optional: check “No reboot” if you don’t want downtime (recommended to leave unchecked for a clean snapshot).
    
5. Click **Create Image** and wait until the AMI status is `Available`.
    

- **Why:** This AMI will be used in the Launch Template so new instances start pre-configured with Docker and your image.
    

---

## **Step 8: Create a Launch Template and attach the AMI**

1. Go to **EC2 → Launch Templates → Create Launch Template**.
    
2. Name it: `project-autoscale-template`.
    
3. Select the AMI created in Step 7.
    
4. Set the **instance type** (e.g., `t2.micro`).
    
5. Attach **security groups** (allow SSH for debugging, app traffic from ALB).
    
6. Assign **IAM role** for SSM if you want to manage instances later.
    
7. Optionally, paste **user-data** to pull the Docker image on boot:
    

```
#!/bin/bash
set -e

# Update system and install dependencies
apt-get update -y
apt-get install -y ca-certificates curl gnupg lsb-release

# Install Docker if not already installed
if ! command -v docker >/dev/null 2>&1; then
  mkdir -p /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
  systemctl enable --now docker
fi

# Docker Hub credentials
DOCKERHUB_USERNAME="your username"
DOCKERHUB_TOKEN="your docker token"
IMAGE="${DOCKERHUB_USERNAME}/project-autoscale:latest"

# Login to Docker Hub
echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin

# Remove old container if exists
docker rm -f project-autoscale || true

# Remove any local copy of the image to force fresh pull
docker image rm -f "$IMAGE" || true

# Pull the latest image from Docker Hub
docker pull --quiet "$IMAGE"

# Run the container
docker run -d --name project-autoscale -p 8080:8080 --restart=always "$IMAGE"
```

---

## **Step 9: Create a Target Group**

1. Go to **EC2 → Target Groups → Create Target Group**.
    
2. Target type: **Instance**.
    
3. Protocol: **HTTP**, Port: `8080` (your app port).
    
4. VPC: select your app’s VPC.
    
5. Health check: path `/` or `/health`.
    
6. Click **Create**.
    

- **Why:** ALB will forward traffic to this TG, and ASG instances will register here.
    

---

## **Step 10: Create a Load Balancer**

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

## **Step 11: Create an Auto Scaling Group and attach everything**

1. Go to **EC2 → Auto Scaling Groups → Create Auto Scaling Group**.
    
2. Name: `project-autoscale-asg`.
    
3. Select the **Launch Template** created in Step 8.
    
4. VPC and subnets: choose multiple AZs for HA.
    
5. Attach to the **ALB / Target Group** from Step 9 & 10.
    
6. Set min/desired/max instances (e.g., 1/1/3).
    
7. Configure scaling policies if needed.
    
8. Click **Create ASG**.
    

---

✅ **End Result:**

- Your app runs at the **ALB DNS name** (port 80 → forwards to 8080).
    
- ASG automatically launches new instances from your AMI + Docker image.
    
- All new instances pull the latest Docker image from Docker Hub.
