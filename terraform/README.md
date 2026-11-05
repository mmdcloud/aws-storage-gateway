# Enterprise Cross-Cloud AWS Storage Gateway (Private S3 File Gateway over HA VPN)

[![Terraform Version](https://img.shields.io/badge/Terraform-%3E%3D1.5-844FBA.svg?logo=terraform)](https://www.terraform.io/)
[![AWS Provider](https://img.shields.io/badge/AWS-~%3E5.0-FF9900.svg?logo=amazon-aws)](https://registry.terraform.io/providers/hashicorp/aws/latest)
[![Google Cloud Provider](https://img.shields.io/badge/GCP-~%3E6.0-4285F4.svg?logo=google-cloud)](https://registry.terraform.io/providers/hashicorp/google/latest)
[![Architecture](https://img.shields.io/badge/Architecture-100%25%20Private%20%7C%20Zero%20Public%20IP-success)](https://aws.amazon.com/storagegateway/)

Production-grade Infrastructure as Code (IaC) deploying an enterprise **AWS Storage Gateway (S3 File Gateway)** configured with **100% private network isolation**. On-premise clients (simulated via Google Cloud Platform) securely access, mount, and synchronize files with Amazon S3 over a **High Availability (HA) Site-to-Site VPN with dynamic BGP routing** and **AWS VPC Endpoints (PrivateLink & Gateway Endpoint)**.

---

## Architecture Overview

```
                      GCP (Simulated On-Premise Datacenter)
                     ┌────────────────────────────────────┐
                     │  On-Prem Client VM (source-vm)     │
                     │  Private IP: 10.10.1.2             │
                     │  Samba / CIFS Client Tools         │
                     └─────────────────┬──────────────────┘
                                       │ 
                                       ▼
                     ┌────────────────────────────────────┐
                     │  GCP Cloud Router (ASN 64514)      │
                     │  GCP HA VPN Gateway (2 Interfaces) │
                     └─────────────────┬──────────────────┘
                                       │
     ══════════════════════════════════╪═════════════════════════════════
       4 Redundant IPsec Tunnels (IKEv2) with BGP Dynamic Peering
       Inside /30 CIDRs: 169.254.10.0/30, .4/30, 169.254.11.0/30, .4/30
     ══════════════════════════════════╪═════════════════════════════════
                                       │
                                       ▼
                     ┌────────────────────────────────────┐
                     │  AWS Virtual Private Gateway (VGW) │
                     │  Amazon ASN: 64512                 │
                     └─────────────────┬──────────────────┘
                                       │
                 AWS Cloud (VPC: 10.0.0.0/16 - Private Subnets)
 ┌─────────────────────────────────────┴──────────────────────────────────────┐
 │                                                                            │
 │  ┌──────────────────────────────────────────────────────────────────────┐  │
 │  │ AWS Storage Gateway Host (EC2 m5.xlarge)                             │  │
 │  │ Private IP: 10.0.4.150  |  Public IP: NONE (Zero Public Exposure)   │  │
 │  │ Attached Local Cache: 150 GiB gp3 (Encrypted at rest)                │  │
 │  └──────────────┬───────────────────────────────────┬───────────────────┘  │
 │                 │                                   │                      │
 │                 ▼ Control Plane                     ▼ Data Plane           │
 │  ┌───────────────────────────────┐   ┌──────────────────────────────────┐  │
 │  │ Storage Gateway VPCE          │   │ Amazon S3 Gateway VPCE           │  │
 │  │ Interface Endpoint (AWS       │   │ Gateway Endpoint (Route Table)   │  │
 │  │ PrivateLink)                  │   │ Zero NAT Gateway Traversal       │  │
 │  └──────────────┬────────────────┘   └──────────────┬───────────────────┘  │
 │                 │                                   │                      │
 └─────────────────┼───────────────────────────────────┼──────────────────────┘
                   │                                   │
                   ▼                                   ▼
   ┌───────────────────────────────┐   ┌──────────────────────────────────┐
   │ AWS Storage Gateway Service   │   │ Amazon S3 Target Bucket          │
   │ (Control & Cloud Management)  │   │ Versioning Enabled + Scoped IAM  │
   └───────────────────────────────┘   └──────────────────────────────────┘
```

---

## Production & Security Highlights

* **100% Private Traffic Flow**: The Storage Gateway EC2 host resides in a private subnet with `associate_public_ip_address = false`. All ingress and egress traffic is constrained to private RFC 1918 addresses.
* **Control Plane via AWS PrivateLink**: Gateway registration, health metrics, and activation are handled through a dedicated Interface VPC Endpoint (`com.amazonaws.<region>.storagegateway`), eliminating internet exposure.
* **Data Plane via S3 Gateway Endpoint**: File uploads and downloads traverse AWS's internal network via a VPC Gateway Endpoint directly into S3, bypassing NAT Gateways and significantly reducing transfer latency and egress costs.
* **HA VPN with 99.99% Redundancy**: 4 active IPsec tunnels between GCP Cloud Router (ASN `64514`) and AWS VGW (ASN `64512`) with BGP route propagation into AWS private route tables.
* **Automated Zero-Touch Activation**: [`scripts/get_activation_key.py`](terraform/scripts/get_activation_key.py) securely fetches the activation key across the VPN from the on-premise client VM via the PrivateLink DNS name and auto-activates the gateway in Terraform. Includes an instant-path bypass for already active gateways.
* **Least-Privilege IAM Policy**: Storage Gateway IAM role is scoped strictly to the target S3 bucket and object ARNs (`s3:GetObject`, `s3:PutObject`, `s3:ListBucket`, etc.) rather than permissive managed policies like `AmazonS3FullAccess`.
* **Mandatory SMB Encryption**: SMB 3.0 in-transit encryption (`seal` flag) enforced for CIFS file shares.
* **Local Cache Disk**: Provisioned with 150 GiB `gp3` (3000 IOPS, 125 MiB/s) encrypted at rest using AWS KMS.

---

## Visual Verification & Infrastructure Evidence

The following operational screenshots document the successful end-to-end deployment, cross-cloud HA VPN peering, private host isolation, SMB mounting, and bidirectional file synchronization with Amazon S3.

### 1. Terraform Automated Deployment
Successful provisioning of 76 resources across AWS and GCP, outputting the private gateway IP (`10.0.4.150`), VPC endpoints, S3 bucket, and 4 BGP tunnel details.

![Terraform Apply Output](screenshots/Screenshot%20from%202026-11-01%2008-13-10.png)

---

### 2. Simulated On-Premise Client (GCP)
GCP Compute Engine instance `source-vm` running in `us-central1-a` with private IP `10.10.1.2`, acting as the enterprise on-premise client.

![GCP VM Instances](screenshots/Screenshot%20from%202026-11-01%2008-13-25.png)

---

### 3. AWS Storage Gateway Appliance & Private Isolation
AWS Storage Gateway `gcp-vm-file-gateway (sgw-1124FF79)` running privately with service endpoint type **VPC** (PrivateLink), bound to private IP `10.0.4.150`.

![AWS Storage Gateway Console](screenshots/Screenshot%20from%202026-11-01%2008-14-00.png)

The underlying EC2 instance (`gateway-instance`) has **NO Public IPv4 Address** and resides in a private subnet, guaranteeing zero public exposure.

![AWS EC2 Instance Summary](screenshots/Screenshot%20from%202026-11-01%2008-14-34.png)

---

### 4. Cross-Cloud HA VPN Connectivity (AWS Side)
Both AWS Site-to-Site VPN connections (`aws-to-gcp-conn-0` and `aws-to-gcp-conn-1`) show **Available** status.

![AWS Site-to-Site VPN Connections](screenshots/Screenshot%20from%202026-11-01%2008-15-30.png)

Virtual Private Gateway (`aws-vgw-gcp`, ASN `64512`) attached to the VPC:

![AWS Virtual Private Gateway](screenshots/Screenshot%20from%202026-11-01%2008-15-49.png)

Customer Gateways (`gcp-customer-gw-0` and `gcp-customer-gw-1`) linked to GCP's HA VPN gateway interfaces (ASN `64514`):

![AWS Customer Gateways](screenshots/Screenshot%20from%202026-11-01%2008-16-01.png)

---

### 5. Cross-Cloud HA VPN & BGP Peering (GCP Side)
GCP Cloud Router `cr-ha-vpn` showing all 4 BGP peering sessions (`bgp-peer-0-1`, `bgp-peer-0-2`, `bgp-peer-1-1`, `bgp-peer-1-2`) in healthy **BGP established** state.

![GCP Cloud Router BGP Sessions](screenshots/Screenshot%20from%202026-11-01%2008-16-35.png)

All 4 GCP IPsec VPN tunnels established to AWS VGW endpoints:

![GCP VPN Tunnels](screenshots/Screenshot%20from%202026-11-01%2008-16-51.png)

---

### 6. SMB File Share Mounting from On-Premise Client
Mounting the private SMB share from the GCP VM across the VPN to `/mnt/aws-storage-gateway` using `vers=3.0,seal` for encrypted transport:

![SMB Share Mount Success](screenshots/Screenshot%20from%202026-11-01%2008-29-12.png)

Filesystem verification (`df -h /mnt/aws-storage-gateway`) showing the virtual 8 Exabyte capacity provided by AWS Storage Gateway:

![Filesystem Verification df -h](screenshots/Screenshot%20from%202026-11-01%2008-29-38.png)

---

### 7. End-to-End Data Ingestion Test (GCP Client → S3)
Creating a test file (`test.txt`) on the mounted SMB share from the GCP VM:

![Write Test File on SMB Share](screenshots/Screenshot%20from%202026-11-01%2008-29-53.png)

Verifying the file locally on the mount point:

![Verify File Content on Client](screenshots/Screenshot%20from%202026-11-01%2008-30-22.png)

The target Amazon S3 bucket (`gcp-simulated-storage-gateway-bucket`):

![Amazon S3 Bucket](screenshots/Screenshot%20from%202026-11-01%2008-30-54.png)

Object `test.txt` instantly persisted to Amazon S3 through the S3 Gateway VPC Endpoint:

![Object Synchronized to S3](screenshots/Screenshot%20from%202026-11-01%2008-31-10.png)

---

### 8. Reverse Synchronization Test (S3 → Storage Gateway Cache → GCP Client)
Directly uploading a file (`1_image_flower.jpg`) into the S3 bucket via the AWS Console:

![Direct S3 Upload](screenshots/Screenshot%20from%202026-11-01%2008-31-46.png)

Both objects (`1_image_flower.jpg` and `test.txt`) present in the S3 bucket:

![S3 Bucket Objects](screenshots/Screenshot%20from%202026-11-01%2008-32-01.png)

Triggering a Storage Gateway cache refresh using the AWS CLI (`refresh-cache`):

![Storage Gateway Cache Refresh](screenshots/Screenshot%20from%202026-11-01%2008-34-48.png)

Verifying reverse synchronization on the GCP client VM: `1_image_flower.jpg` is immediately visible on `/mnt/aws-storage-gateway`:

![Client Visibility of S3 File](screenshots/Screenshot%20from%202026-11-01%2008-35-09.png)

---

## Repository Structure

```
.
├── README.md                  # Comprehensive production architecture and operational documentation
├── screenshots/               # Visual proof and operational verification screenshots
│   ├── Screenshot from 2026-11-01 08-13-10.png  # Terraform Apply Outputs
│   ├── Screenshot from 2026-11-01 08-13-25.png  # GCP VM Instance
│   ├── Screenshot from 2026-11-01 08-14-00.png  # AWS Storage Gateway Console
│   ├── Screenshot from 2026-11-01 08-14-34.png  # EC2 Host Summary (No Public IP)
│   ├── Screenshot from 2026-11-01 08-15-30.png  # AWS Site-to-Site VPN Connections
│   ├── Screenshot from 2026-11-01 08-15-49.png  # AWS Virtual Private Gateway
│   ├── Screenshot from 2026-11-01 08-16-01.png  # AWS Customer Gateways
│   ├── Screenshot from 2026-11-01 08-16-35.png  # GCP Cloud Router BGP Sessions
│   ├── Screenshot from 2026-11-01 08-16-51.png  # GCP HA VPN Tunnels
│   ├── Screenshot from 2026-11-01 08-29-12.png  # Mount SMB Share on GCP VM
│   ├── Screenshot from 2026-11-01 08-29-38.png  # Filesystem Verification (df -h)
│   ├── Screenshot from 2026-11-01 08-29-53.png  # Write test.txt on SMB Share
│   ├── Screenshot from 2026-11-01 08-30-22.png  # Verify test.txt locally
│   ├── Screenshot from 2026-11-01 08-30-54.png  # S3 Bucket Console
│   ├── Screenshot from 2026-11-01 08-31-10.png  # S3 Object Sync Verification
│   ├── Screenshot from 2026-11-01 08-31-46.png  # Direct S3 Upload of Image
│   ├── Screenshot from 2026-11-01 08-32-01.png  # S3 Objects List
│   ├── Screenshot from 2026-11-01 08-34-48.png  # SGW Cache Refresh Command
│   └── Screenshot from 2026-11-01 08-35-09.png  # Reverse Sync Verification on GCP VM
└── terraform/
    ├── main.tf                # Core orchestration: VPC, HA VPN, VPC Endpoints, SGW & S3
    ├── variables.tf           # 7 structured sections with strict types and validation blocks
    ├── outputs.tf             # Comprehensive endpoints, S3 details, mount commands, and VPN audit maps
    ├── provider.tf            # AWS, Google, Random, External, and Time provider definitions
    ├── terraform.tfvars       # Environment-specific configuration values
    ├── terraform.tfvars.example # Documented template for spinning up new environments (dev/stage/prod)
    ├── scripts/
    │   ├── get_activation_key.py # Automation script to fetch SGW activation key across the VPN
    │   └── user_data.sh       # Bootstrap script for GCP VM (Samba, cifs-utils & mount helper)
    └── modules/
        ├── aws/
        │   ├── ec2/           # EC2 instance module with IAM profiles & unified tagging
        │   ├── s3/            # S3 bucket module with CORS, versioning, and lifecycle support
        │   ├── storage-gateway/ # Storage Gateway appliance, cache volume & SMB share module
        │   └── vpc/           # VPC module & Security Group submodules
        └── gcp/
            ├── compute/       # GCP Compute Engine module with metadata scripts & labels
            └── vpc/           # GCP VPC network, subnets & firewall rules module
```

---

## Prerequisites

1. **Terraform**: `>= 1.5.0` installed.
2. **AWS CLI (`aws`)**: Configured with IAM credentials having permissions for VPC, EC2, Storage Gateway, S3, IAM, and VPN (`aws configure`).
3. **Google Cloud SDK (`gcloud`)**: Authenticated and set to target project (`gcloud auth application-default login` and `gcloud config set project <PROJECT_ID>`).
4. **Python 3**: With standard library (`subprocess`, `urllib`, `json`).

---

## Configuration Reference (`variables.tf`)

### 1. Project & Environment Metadata
| Variable | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `project_name` | `string` | `"storage-gw"` | Identifier used for naming and tagging. |
| `environment` | `string` | `"prod"` | Environment (`dev`, `stage`, `staging`, `prod`). |
| `tags` | `map(string)` | `{}` | Additional AWS tags merged with common tags. |
| `gcp_labels` | `map(string)` | `{}` | Key/value labels attached to GCP resources. |

### 2. AWS VPC & Network
| Variable | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `aws_region` | `string` | `"us-east-1"` | AWS Region for VPC and Storage Gateway. |
| `aws_vpc_cidr` | `string` | `"10.0.0.0/16"` | IPv4 CIDR block for the AWS VPC. |
| `azs` | `list(string)` | `["us-east-1a", ...]` | Availability Zones. |
| `public_subnets` | `list(string)` | `["10.0.1.0/24", ...]`| Public Subnet CIDRs (for VPN/NAT). |
| `private_subnets`| `list(string)` | `["10.0.4.0/24", ...]`| Private Subnet CIDRs (SGW deployed in index `0`). |
| `enable_nat_gateway` | `bool` | `true` | Enable NAT Gateway for outbound traffic. |
| `single_nat_gateway` | `bool` | `true` | Single NAT Gateway to optimize costs (set false for multi-AZ). |

### 3. Cross-Cloud HA VPN & BGP
| Variable | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `aws_bgp_asn` | `number` | `64512` | BGP ASN for AWS VGW (must be private ASN). |
| `gcp_bgp_asn` | `number` | `64514` | BGP ASN for GCP Cloud Router (must be private ASN). |
| `bgp_advertised_route_priority` | `number` | `100` | Base priority for routes advertised to AWS. |
| `vpn_tunnel_inside_cidrs` | `map(string)` | *4x /30 CIDRs* | Inside CIDR ranges (`169.254.10.0/30`, etc.). |

### 4. AWS Storage Gateway Appliance
| Variable | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `gateway_name` | `string` | `"gcp-vm-file-gateway"` | Storage Gateway appliance name. |
| `gateway_instance_type`| `string` | `"m5.xlarge"` | EC2 host type (min 4 vCPU / 16 GiB RAM). |
| `cache_disk_size` | `number` | `150` | Cache EBS volume size in GiB (min 150 GiB). |
| `cache_disk_type` | `string` | `"gp3"` | EBS volume type for cache disk. |
| `cache_disk_encrypted`| `bool` | `true` | Encrypt local cache EBS volume at rest. |
| `activation_key` | `string` | `null` | Optional key (retrieved automatically if null). |

### 5. S3 Target & Security
| Variable | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `s3_bucket_name` | `string` | `"gcp-simulated-storage-gateway-bucket"` | Target S3 bucket backing the SMB share. |
| `s3_force_destroy` | `bool` | `false` | Prevent accidental data loss on destroy. |
| `s3_versioning_enabled` | `string` | `"Enabled"` | Enable object versioning in S3. |
| `enable_least_privilege_iam` | `bool` | `true` | Enforce scoped IAM policy over `FullAccess`. |

### 6. SMB File Share
| Variable | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `smb_guest_password` | `string` | `"GuestPass123!"` | Sensitive password for `smbguest` user. |
| `smb_authentication` | `string` | `"GuestAccess"` | `GuestAccess` or `ActiveDirectory`. |
| `smb_read_only` | `bool` | `false` | Whether the SMB share is read-only. |
| `smb_guess_mime_type`| `bool` | `true` | Enable MIME type guessing on S3 upload. |

---

## Deployment Guide

### Step 1: Clone and Configure Environment

```bash
cd /home/shiv/mohit/aws-storage-gateway/terraform

# Copy the example variables template
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your project identifiers:
```hcl
gcp_project        = "your-gcp-project-id"
aws_region         = "us-east-1"
gcp_region         = "us-central1"
s3_bucket_name     = "your-company-storage-gateway-bucket"
smb_guest_password = "YourSuperSecretPassword123!"
```

### Step 2: Initialize & Validate

```bash
terraform init
terraform validate
```

### Step 3: Plan and Apply

```bash
terraform plan -out=tfplan
terraform apply tfplan
```

> [!NOTE]
> During a fresh deployment, EC2 instance boot, IPsec tunnel handshake, and BGP route establishment take approximately **2 to 3 minutes**. The [`scripts/get_activation_key.py`](terraform/scripts/get_activation_key.py) script polls over the VPN and automatically registers the appliance once BGP converges.

---

## Testing & Verification Runbook (5-Stage Operational Guide)

Once `terraform apply` finishes, perform the following verification stages from the GCP client VM:

### Stage 1: Connect to the GCP On-Premise VM

```bash
gcloud compute ssh source-vm --zone=us-central1-a --project=<GCP_PROJECT_ID>
```

### Stage 2: Verify VPN & BGP Dynamic Routing (Layer 3)

1. Verify route to the AWS private subnet:
   ```bash
   ip route get 10.0.4.150
   ```
   *Expected Output*: Routed via `cr-interface-...` tunnel interface, not the default internet route.

2. Test ICMP reachability to the Storage Gateway private IP:
   ```bash
   ping -c 4 10.0.4.150
   ```
   *Expected Output*: `0% packet loss` with consistent low round-trip latency.

### Stage 3: Test Private SMB Port over VPN (Layer 4)

```bash
nc -zv 10.0.4.150 445
```
*Expected Output*:
```text
Connection to 10.0.4.150 445 port [tcp/microsoft-ds] succeeded!
```

### Stage 4: Mount the SMB File Share Privately

Use the pre-installed helper script or run the standard CIFS mount command with the current gateway IP:

```bash
sudo /home/admin/mount-aws-storage-gateway.sh 10.0.4.150 gcp-simulated-storage-gateway-bucket GuestPass123!
```

Or manually:
```bash
sudo mkdir -p /mnt/aws-storage-gateway
sudo mount -t cifs "//10.0.4.150/gcp-simulated-storage-gateway-bucket" /mnt/aws-storage-gateway \
  -o username=smbguest,password="GuestPass123!",vers=3.0,seal
```

> [!IMPORTANT]
> **Why `vers=3.0,seal` is required:**
> AWS Storage Gateway enforces in-transit encryption (`MandatoryEncryption`) by default. Without the `seal` flag and SMB `vers=3.0`, the Linux kernel CIFS client fails with `mount error(13): Permission denied`.

Verify the active mount:
```bash
df -h /mnt/aws-storage-gateway
mount | grep cifs
```

### Stage 5: Test End-to-End Data Synchronization

#### 1. Ingestion Test (GCP Client → S3)
On the GCP VM, write a test file:
```bash
echo "Enterprise Storage Gateway over HA VPN - $(date)" | sudo tee /mnt/aws-storage-gateway/production-test.txt
```

Verify in Amazon S3 (from host terminal or AWS console):
```bash
aws s3 ls s3://gcp-simulated-storage-gateway-bucket/
aws s3 cp s3://gcp-simulated-storage-gateway-bucket/production-test.txt -
```

#### 2. Reverse Sync Test (S3 → Storage Gateway Cache → GCP Client)
Directly create an object in S3:
```bash
echo "Direct S3 object" | aws s3 cp - s3://gcp-simulated-storage-gateway-bucket/s3-origin.txt
```

Trigger gateway cache refresh:
```bash
aws storagegateway refresh-cache \
  --file-share-arn $(terraform output -json smb_share_arns | jq -r '.[0]') \
  --region us-east-1
```

Verify visibility on GCP VM:
```bash
cat /mnt/aws-storage-gateway/s3-origin.txt
```

---

## Day-2 Operations & Monitoring

### CloudWatch Monitoring Metrics
The following metrics in the `AWS/StorageGateway` namespace should be monitored via CloudWatch alarms:
* `CacheHitPercent`: Percentage of read operations served directly from the EBS local cache. Target: `> 80%`.
* `UploadBufferUsed`: High watermark indicator for write buffer saturation.
* `CachePercentDirty`: Percentage of cache waiting to be persisted to S3.

### Cache Refresh Automation
To ensure out-of-band updates to the S3 bucket reflect on the on-premise mount without manual intervention, schedule a periodic cache refresh via AWS EventBridge and Lambda, or configure automated S3 bucket notifications.

---

## Troubleshooting Runbook

| Symptom / Error | Root Cause | Resolution |
| :--- | :--- | :--- |
| `mount error(13): Permission denied` | Missing SMB encryption (`seal`) or incorrect guest password. | Add `vers=3.0,seal` to mount options. Confirm `smb_guest_password` matches `smbguest`. |
| `mount error(115): Operation now in progress` | Client sending packets to an old / stale gateway IP address. | Check current private IP via `terraform output gateway_private_ip` (e.g. `10.0.4.150`) and re-run mount. |
| `Connection timed out` on port 445 | AWS Security Group or GCP Firewall blocking TCP 445. | Verify `gateway-sg` allows TCP 445 from `source_vpc_ip_cidr_range` (`10.10.1.0/24`). |
| Ping to `10.0.4.150` fails | BGP routes have not propagated to the AWS private route table. | Verify `aws_vpn_gateway_route_propagation.private` is enabled on the route table. Check GCP Cloud Router BGP state. |
| `InvalidGatewayRequestException` on activation | Attempting to pass `gateway_vpc_endpoint` alongside `activation_key` in `aws_storagegateway_gateway`. | Terraform module dynamically sets `gateway_vpc_endpoint = null` when an `activation_key` is provided. |
| Activation key retrieval timeout | EC2 instance or IPsec tunnels still initializing during fresh apply. | Ensure timeout in [`get_activation_key.py`](terraform/scripts/get_activation_key.py) allows 3 minutes for BGP convergence. |

---

## Teardown Procedure

To cleanly destroy all infrastructure without leaving orphaned VPC endpoints or dangling Storage Gateway registrations:

```bash
# 1. Unmount the share on the GCP VM (if active)
sudo umount -f /mnt/aws-storage-gateway

# 2. If s3_force_destroy is false and objects remain in S3, empty the bucket:
aws s3 rm s3://gcp-simulated-storage-gateway-bucket --recursive

# 3. Destroy infrastructure via Terraform
terraform destroy -auto-approve
```
