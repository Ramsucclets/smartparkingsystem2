# AWS Amplify to EC2 Migration Guide

Migrate the Smart Parking System frontend from AWS Amplify to EC2 with Application Load Balancer (ALB) and Auto Scaling.

## Configuration Summary

| Setting       | Value                            |
| ------------- | -------------------------------- |
| Instance Type | t3.small                         |
| Domain        | app.smarpar.site                 |
| DNS Provider  | Cloudflare                       |
| VPC           | New (created in this guide)      |
| CI/CD         | Manual (local build + S3 upload) |
| Region        | us-east-1 (same as existing)     |

---

## Step 1: Create VPC (Manual Setup)

### 1.1 Create the VPC

1. Open AWS Console: https://console.aws.amazon.com/vpc/
2. **Verify region** is `us-east-1` (N. Virginia) in top-right
3. In left sidebar, click **Your VPCs** → **Create VPC**
4. Select **VPC only**
5. Configure:
   | Field | Value |
   |-------|-------|
   | **Name tag** | `smarpar-vpc` |
   | **IPv4 CIDR block** | `10.0.0.0/16` |
   | **IPv6 CIDR block** | No IPv6 CIDR block |
   | **Tenancy** | Default |
6. Click **Create VPC**
7. Note the **VPC ID** (e.g., `vpc-0abc123...`)

---

### 1.2 Create Internet Gateway

1. In left sidebar, click **Internet gateways** → **Create internet gateway**
2. **Name tag**: `smarpar-igw`
3. Click **Create internet gateway**
4. On the next page, click **Actions** → **Attach to VPC**
5. Select `smarpar-vpc` → Click **Attach internet gateway**

---

### 1.3 Create Subnet (Single AZ)

1. In left sidebar, click **Subnets** → **Create subnet**
2. Configure:
   | Field | Value |
   |-------|-------|
   | **VPC ID** | Select `smarpar-vpc` |
   | **Subnet name** | `smarpar-subnet-public` |
   | **Availability Zone** | `us-east-1a` |
   | **IPv4 CIDR block** | `10.0.1.0/24` |
3. Click **Create subnet**

---

### 1.4 Enable Auto-assign Public IP

1. Select `smarpar-subnet-public`
2. Click **Actions** → **Edit subnet settings**
3. Check ✅ **Enable auto-assign public IPv4 address**
4. Click **Save**

---

### 1.5 Create Route Table

1. In left sidebar, click **Route tables** → **Create route table**
2. Configure:
   | Field | Value |
   |-------|-------|
   | **Name** | `smarpar-rtb-public` |
   | **VPC** | `smarpar-vpc` |
3. Click **Create route table**

---

### 1.6 Add Internet Route

1. Select the newly created `smarpar-rtb-public`
2. Click **Routes** tab → **Edit routes** → **Add route**
3. Configure:
   | Field | Value |
   |-------|-------|
   | **Destination** | `0.0.0.0/0` |
   | **Target** | Select **Internet Gateway** → `smarpar-igw` |
4. Click **Save changes**

---

### 1.7 Associate Subnet with Route Table

1. Still on `smarpar-rtb-public`, click **Subnet associations** tab
2. Click **Edit subnet associations**
3. Check: ✅ `smarpar-subnet-public`
4. Click **Save associations**

---

### 1.8 Verify Setup

| Resource         | Name                    | Status                              |
| ---------------- | ----------------------- | ----------------------------------- |
| VPC              | `smarpar-vpc`           | CIDR: `10.0.0.0/16`                 |
| Internet Gateway | `smarpar-igw`           | Attached to VPC                     |
| Subnet           | `smarpar-subnet-public` | AZ: us-east-1a, CIDR: `10.0.1.0/24` |
| Route Table      | `smarpar-rtb-public`    | Route `0.0.0.0/0` → `smarpar-igw`   |

> **IMPORTANT**: Save these IDs: VPC ID (`vpc-xxx`) and Subnet ID (`subnet-xxx`)

---

## Step 2: Create Security Groups

### ALB Security Group

1. **VPC Console** → **Security Groups** → **Create security group**
2. Configure:
   - **Name**: `smarpar-alb-sg`
   - **VPC**: `smarpar-vpc`
   - **Inbound rules**:
     | Type | Port | Source |
     |------|------|--------|
     | HTTP | 80 | 0.0.0.0/0 |
     | HTTPS | 443 | 0.0.0.0/0 |

### EC2 Security Group

1. Create another security group:
   - **Name**: `smarpar-ec2-sg`
   - **VPC**: `smarpar-vpc`
   - **Inbound rules**:
     | Type | Port | Source |
     |------|------|--------|
     | HTTP | 80 | smarpar-alb-sg |
     | SSH | 22 | Your IP (optional, for debugging) |

---

## Step 3: Create S3 Bucket for Builds

1. **S3 Console** → **Create bucket**
2. Configure:
   - **Name**: `smarpar-flutter-builds`
   - **Region**: `us-east-1`
   - **Block all public access**: ✅ Keep enabled
3. Create folder: `builds/`

---

## Step 4: Use Existing IAM Role (LabRole)

Since you're using AWS Learner Lab, use the pre-existing `LabRole`:

1. **IAM Console** → **Roles**
2. Search for `LabRole`
3. Click on it and verify it has S3 access (it should by default)
4. Note the role name: `LabRole`

> **NOTE**: LabRole is automatically created by AWS Learner Lab and has broad permissions including S3 read/write. No need to create a new role.

---

## Step 5: Create Launch Template

1. **EC2 Console** → **Launch Templates** → **Create launch template**
2. Configure:
   - **Name**: `smarpar-web-template`
   - **AMI**: Amazon Linux 2023 AMI
   - **Instance type**: `t3.small`
   - **Key pair**: Select or create one (for SSH access)
   - **Security groups**: `smarpar-ec2-sg`
   - **IAM instance profile**: `LabRole`
   - **User data** (paste in Advanced details):

```bash
#!/bin/bash
yum update -y
yum install -y nginx aws-cli

# Download Flutter web build from S3
aws s3 sync s3://smarpar-flutter-builds/builds/latest/web/ /usr/share/nginx/html/

# Configure nginx
cat > /etc/nginx/conf.d/flutter.conf << 'EOF'
server {
    listen 80;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

# Remove default config
rm -f /etc/nginx/conf.d/default.conf

# Start nginx
systemctl enable nginx
systemctl start nginx
```

---

## Step 6: Create Target Group

1. **EC2 Console** → **Target Groups** → **Create target group**
2. Configure:
   - **Target type**: Instances
   - **Name**: `smarpar-tg`
   - **Protocol**: HTTP, Port 80
   - **VPC**: `smarpar-vpc`
   - **Health check path**: `/`
3. Click **Create** (don't register targets yet)

---

## Step 7: Create Application Load Balancer

1. **EC2 Console** → **Load Balancers** → **Create load balancer**
2. Select **Application Load Balancer**
3. Configure:
   - **Name**: `smarpar-alb`
   - **Scheme**: Internet-facing
   - **VPC**: `smarpar-vpc`
   - **Mappings**: Select `smarpar-subnet-public`
   - **Security groups**: `smarpar-alb-sg`
   - **Listener**: HTTP:80 → Forward to `smarpar-tg`
4. Click **Create**

> **TIP**: Copy the ALB DNS name (e.g., `smarpar-alb-123456.us-east-1.elb.amazonaws.com`) — you'll need it for Cloudflare.

---

## Step 8: Create Auto Scaling Group

1. **EC2 Console** → **Auto Scaling Groups** → **Create**
2. Configure:
   - **Name**: `smarpar-asg`
   - **Launch template**: `smarpar-web-template`
   - **VPC**: `smarpar-vpc`, select `smarpar-subnet-public`
   - **Load balancing**: Attach to `smarpar-tg`
   - **Group size**: Min 1, Desired 2, Max 4
   - **Scaling policies**: Target tracking, CPU 70%

---

## Step 9: Manual Deployment (Learner Lab Compatible)

Since CodeBuild/CodePipeline are not available in Learner Lab, use manual deployment:

### 9.1 Build Locally

Run these commands on your local machine:

```powershell
# Build Flutter web
flutter build web --release --no-tree-shake-icons
```

### 9.2 Upload to S3

**Option A: AWS CLI** (if configured)

```powershell
aws s3 sync build/web/ s3://smarpar-flutter-builds/builds/latest/web/ --delete
```

**Option B: AWS Console**

1. Go to **S3 Console** → `smarpar-flutter-builds` bucket
2. Navigate to `builds/latest/web/` folder (create if needed)
3. Click **Upload** → Drag all files from `build/web/`
4. Click **Upload**

### 9.3 Refresh EC2 Instances

After uploading, trigger the instances to pull the new build:

1. **EC2 Console** → **Auto Scaling Groups** → `smarpar-asg`
2. Click **Instance refresh** tab → **Start instance refresh**
3. Set **Minimum healthy percentage**: `50`
4. Click **Start instance refresh**

> **TIP**: Instance refresh replaces instances one by one with fresh ones that download the latest build from S3.

---

## Step 10: Update Cloudflare DNS

1. Login to **Cloudflare Dashboard**
2. Select zone `smarpar.site`
3. Go to **DNS** → **Records**
4. Update `app` record:
   - **Type**: CNAME
   - **Name**: app
   - **Target**: `smarpar-alb-XXXXXX.us-east-1.elb.amazonaws.com`
   - **Proxy status**: DNS only (grey cloud) — ALB handles SSL

> **IMPORTANT**: If you want Cloudflare to proxy (orange cloud), you need to add an HTTPS listener to your ALB with an ACM certificate. Otherwise, use grey cloud (DNS only).

---

## Step 11: Initial Deployment

1. Build locally and upload to S3:

```bash
flutter build web --release --no-tree-shake-icons
aws s3 sync build/web/ s3://smarpar-flutter-builds/builds/latest/web/ --delete
```

2. Trigger instance refresh in ASG
3. Test: Open `http://app.smarpar.site`

---

## Rollback Plan

If issues occur:

1. Keep Amplify active until EC2 verified
2. Switch Cloudflare CNAME back to Amplify domain
3. Delete resources manually if needed

---
