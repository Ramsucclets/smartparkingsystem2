# AWS Setup - Presentation Slides

---

## Slide 0: Latar Belakang (Background)

### 🔴 Problem Statement

**Tantangan Infrastruktur Tradisional:**

| Masalah                         | Dampak                                                                                     |
| ------------------------------- | ------------------------------------------------------------------------------------------ |
| 💰 **Pembelian Hardware Mahal** | Investasi awal besar (CapEx) untuk server, storage, networking, UPS, cooling system        |
| 📈 **Kurangnya Skalabilitas**   | Over-provisioning = pemborosan biaya; Under-provisioning = downtime & kehilangan pelanggan |
| 🔧 **Maintenance Kompleks**     | Butuh tim IT dedicated untuk pemeliharaan hardware 24/7, update firmware, patching         |
| ⏰ **Time-to-Market Lambat**    | Procurement hardware bisa memakan waktu berminggu-minggu hingga berbulan-bulan             |
| ⚠️ **Single Point of Failure**  | Hardware rusak = sistem down, tidak ada redundancy tanpa investasi tambahan                |
| 🔒 **Keamanan & Compliance**    | Harus mengelola sendiri security patches, firewall, dan compliance requirements            |

```
Ilustrasi Masalah Skalabilitas:

Traffic ▲
        │     ╭──────╮  Peak Traffic (tidak bisa handle)
        │    ╱        ╲
        │   ╱          ╲
   ─────┼──╱────────────╲───── Kapasitas Server (Fixed)
        │ ╱              ╲
        │╱   Wasted       ╲
        │    Resources
        └─────────────────────▶ Waktu

   ❌ Over-provisioning = bayar untuk kapasitas yang tidak digunakan
   ❌ Under-provisioning = downtime saat peak traffic
```

### 🟢 Solution Overview

**Cloud Adoption dengan Model Pay-As-You-Go**

Menggunakan layanan AWS untuk menggantikan infrastruktur on-premise dengan pendekatan yang lebih fleksibel dan efisien.

**Prinsip Utama:**

- ☁️ **No Upfront Cost** - Tidak perlu investasi hardware di awal
- 💳 **Pay-As-You-Go** - Bayar hanya untuk resource yang benar-benar digunakan
- 🔄 **Elastic Scaling** - Scale up/down sesuai kebutuhan dalam hitungan menit
- 🌍 **Global Infrastructure** - Leverage AWS data centers di seluruh dunia

**AWS Services yang Digunakan:**

| Kebutuhan      | Traditional         | AWS Solution                                         |
| -------------- | ------------------- | ---------------------------------------------------- |
| Compute        | Physical Server     | **EC2** (Virtual Machines) + **Lambda** (Serverless) |
| Database       | MySQL Server        | **DynamoDB** (Managed NoSQL)                         |
| Storage        | SAN/NAS             | **S3** (Object Storage)                              |
| Load Balancing | F5/HAProxy Hardware | **ALB** (Application Load Balancer)                  |
| Scaling        | Manual              | **Auto Scaling Group**                               |
| Authentication | Custom Auth Server  | **Cognito** (Managed Auth)                           |
| API Management | Custom API Server   | **API Gateway**                                      |
| DNS            | BIND Server         | **Route 53** / Cloudflare                            |

```
Ilustrasi Cloud Scaling:

Traffic ▲
        │     ╭──────╮  Peak Traffic
        │    ╱   ✅   ╲ ← Auto Scale UP
        │   ╱──────────╲
   ─────┼──╱────────────╲───── Kapasitas Dinamis
        │ ╱              ╲
        │╱    ✅ Scale    ╲
        │      DOWN
        └─────────────────────▶ Waktu

   ✅ Kapasitas selalu match dengan demand
   ✅ Bayar hanya untuk yang digunakan
```

### ✨ Key Benefits

#### 1. 💵 Cost Efficiency

- **Eliminasi CapEx** → Berubah ke model OpEx (operational expense)
- **Bayar sesuai pemakaian** → Tidak ada idle resources
- **Estimasi biaya**: Dari ~Rp 200jt/tahun (traditional) → ~Rp 10jt/tahun (cloud) untuk workload serupa

#### 2. 🛡️ High Availability

- **Multi-AZ Deployment** → Aplikasi berjalan di 2+ Availability Zone
- **99.99% Uptime SLA** → AWS menjamin ketersediaan layanan
- **Automatic Failover** → Jika satu AZ down, traffic otomatis dialihkan

#### 3. 📊 Flexibility & Scalability

- **Horizontal Scaling** → Tambah instance saat traffic tinggi
- **Vertical Scaling** → Upgrade instance type jika butuh lebih banyak resource
- **Auto Scaling** → Scaling otomatis berdasarkan metrics (CPU, memory, request count)

#### 4. ⚡ On-Demand Resources

- **Provisioning dalam menit** → Bukan minggu/bulan seperti traditional
- **Self-service** → Developer bisa deploy tanpa menunggu IT procurement
- **Infrastructure as Code** → Reproducible & version-controlled infrastructure

### 📊 Perbandingan: Traditional vs Cloud

| Aspek                 | Traditional Infrastructure | Cloud (AWS)                |
| --------------------- | -------------------------- | -------------------------- |
| **Initial Cost**      | 💰💰💰 Tinggi (CapEx)      | 💰 Rendah (mulai dari $0)  |
| **Scaling Time**      | ⏰ Minggu - Bulan          | ⚡ Menit                   |
| **Maintenance**       | 🔧 Tim IT dedicated        | 🤖 Managed by AWS          |
| **Availability**      | ⚠️ Single DC (99.9%)       | ✅ Multi-AZ (99.99%)       |
| **Disaster Recovery** | 💰💰 Mahal (2nd DC)        | ✅ Built-in (Cross-Region) |
| **Security Updates**  | 🔒 Manual patching         | 🔄 Auto-managed            |
| **Capacity Planning** | 📈 Harus prediksi demand   | 🔄 Elastic, sesuai demand  |
| **Global Reach**      | 🌍 Sulit & mahal           | 🌍 Deploy ke 30+ regions   |

### 🎯 Mengapa AWS untuk Smart Parking System?

1. **IoT Integration** → AWS IoT Core untuk koneksi sensor
2. **Serverless Backend** → Lambda + API Gateway untuk efisiensi biaya
3. **Real-time Database** → DynamoDB dengan millisecond latency
4. **Scalable Frontend** → EC2 + ALB + Auto Scaling untuk handle traffic spikes
5. **AWS Academy/Learner Lab** → Free tier untuk pembelajaran & development

---

## Slide 1: Network Foundation

    ### VPC & Networking

    - Buat **VPC** dengan CIDR `10.0.0.0/16`
    - Buat **Internet Gateway** dan attach ke VPC
    - Buat **2 Public Subnets** di Availability Zone berbeda:
    - `10.0.1.0/24` (us-east-1a)
    - `10.0.2.0/24` (us-east-1b)
    - Buat **Route Table** dengan route `0.0.0.0/0 → IGW`

    ### Security Groups

    - **ALB Security Group**: Allow HTTP (80), HTTPS (443) from anywhere
    - **EC2 Security Group**: Allow HTTP (80) from ALB-SG only

    ---

    ## Slide 2: Compute & Load Balancing

    ### S3 & Launch Template

    - Buat **S3 Bucket** untuk Flutter web builds
    - Buat **Launch Template**:
    - AMI: Amazon Linux 2023
    - Instance type: t3.small
    - User data: Install nginx, sync dari S3

    ### Load Balancer & Auto Scaling

    - Buat **Target Group** (HTTP:80, health check: `/`)
    - Buat **Application Load Balancer** (Internet-facing, 2 AZ)
    - Buat **Auto Scaling Group**:
    - Min: 1, Desired: 2, Max: 4
    - Scaling policy: CPU > 70%

    ---

    ## Slide 3: Backend Services (Serverless)

    ### Database

    - Buat **DynamoDB Table** `parking_spots`
    - Partition key: `spotId`
    - Sort key: `floorId` (optional)

    ### API & Functions

    - Buat **Lambda Function** untuk business logic
    - Runtime: Python 3.12 / Node.js 20.x
    - Role: LabRole
    - Buat **API Gateway** (REST API)
    - Resources: `/parking`, `/spots`, `/floors`
    - Methods: GET, POST, PUT, DELETE
    - Integration: Lambda Function

    ### Authentication

    - Buat **Cognito User Pool** untuk user management
    - Sign-in: Email
    - App client untuk web app

    ---

    ## Slide 4: DNS & Deployment

    ### Cloudflare Configuration

    - Tambah **CNAME record**:
    - Name: `app`
    - Target: ALB DNS name
    - Proxy: DNS only (grey cloud)

    ### Deployment Process

    1. **Build locally**: `flutter build web --release`
    2. **Upload ke S3**: `aws s3 sync build/web/ s3://bucket/builds/`
    3. **Trigger Instance Refresh** di ASG
    4. **Verify**: Akses `app.smarpar.site`

    ### High Availability Features

    - ✅ Multi-AZ deployment (2 Availability Zones)
    - ✅ Auto Scaling (1-4 instances based on CPU)
    - ✅ Load Balancing (ALB distributes traffic)
    - ✅ Health Checks (automatic unhealthy instance replacement)
