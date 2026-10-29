# =============================================================================
# Section 1: Project & Environment Metadata
# =============================================================================

variable "project_name" {
  type        = string
  description = "Project identifier used for consistent resource naming and tagging"
  default     = "storage-gw"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "project_name must contain only lowercase alphanumeric characters and hyphens."
  }
}

variable "environment" {
  type        = string
  description = "Deployment environment name (e.g., dev, staging, prod)"
  default     = "prod"

  validation {
    condition     = contains(["dev", "test", "stage", "staging", "prod", "production"], lower(var.environment))
    error_message = "environment must be one of: dev, test, stage, staging, prod, production."
  }
}

variable "tags" {
  type        = map(string)
  description = "Additional tags to apply to all AWS resources"
  default     = {}
}

variable "gcp_labels" {
  type        = map(string)
  description = "Key/value labels to apply to GCP resources"
  default     = {}
}

# =============================================================================
# Section 2: GCP Simulated On-Premise Environment
# =============================================================================

variable "gcp_project" {
  type        = string
  description = "GCP Project ID hosting the simulated on-premise environment"

  validation {
    condition     = length(var.gcp_project) > 0
    error_message = "gcp_project cannot be empty."
  }
}

variable "gcp_region" {
  type        = string
  description = "GCP Region for the simulated on-premise environment"
  default     = "us-central1"
}

variable "gcp_zone" {
  type        = string
  description = "GCP Zone for compute resources (defaults to '<gcp_region>-a' if null)"
  default     = null
}

variable "gcp_vpc_name" {
  type        = string
  description = "Name of the GCP VPC representing the on-premise network"
  default     = "source-vpc"
}

variable "source_vpc_ip_cidr_range" {
  type        = list(string)
  description = "GCP VPC Subnet CIDR ranges (simulated on-premise network)"
  default     = ["10.10.1.0/24"]
}

variable "gcp_router_name" {
  type        = string
  description = "Name of the GCP Cloud Router for BGP peering"
  default     = "cr-ha-vpn"
}

variable "gcp_ha_vpn_gw_name" {
  type        = string
  description = "Name of the GCP HA VPN Gateway"
  default     = "gcp-ha-vpn-gw"
}

variable "gcp_external_vpn_gw_name" {
  type        = string
  description = "Name of the GCP External VPN Gateway referencing AWS endpoints"
  default     = "peer-gw"
}

variable "gcp_vm_name" {
  type        = string
  description = "Name of the GCP simulated on-premise client VM"
  default     = "source-vm"
}

variable "gcp_vm_ip_name" {
  type        = string
  description = "Name of the static public IP reservation for the GCP VM"
  default     = "source-vm-address"
}

variable "gcp_vm_machine_type" {
  type        = string
  description = "Machine type for the GCP simulated on-premise VM"
  default     = "e2-medium"
}

variable "gcp_vm_image" {
  type        = string
  description = "OS boot image for the GCP VM"
  default     = "ubuntu-os-cloud/ubuntu-2004-focal-v20220712"
}

variable "gcp_vm_deletion_protection" {
  type        = bool
  description = "Enable deletion protection on the GCP client VM"
  default     = false
}

variable "gcp_allowed_ssh_cidrs" {
  type        = list(string)
  description = "Allowed CIDR ranges for administrative SSH ingress to the GCP VM"
  default     = ["0.0.0.0/0"]
}

# =============================================================================
# Section 3: AWS VPC & Networking
# =============================================================================

variable "aws_region" {
  type        = string
  description = "AWS Region for VPC, Storage Gateway, and S3"
  default     = "us-east-1"
}

variable "aws_vpc_name" {
  type        = string
  description = "Name of the AWS VPC"
  default     = "vpc"
}

variable "aws_vpc_cidr" {
  type        = string
  description = "IPv4 CIDR block for the AWS VPC"
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.aws_vpc_cidr, 0))
    error_message = "aws_vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "azs" {
  type        = list(string)
  description = "List of AWS Availability Zones"
}

variable "public_subnets" {
  type        = list(string)
  description = "AWS Public Subnet CIDR values"
}

variable "private_subnets" {
  type        = list(string)
  description = "AWS Private Subnet CIDR values (Storage Gateway resides in private_subnets[0])"
}

variable "database_subnets" {
  type        = list(string)
  description = "AWS Database Subnet CIDR values"
  default     = []
}

variable "enable_nat_gateway" {
  type        = bool
  description = "Enable NAT Gateway for private subnets (needed if outbound internet is required)"
  default     = true
}

variable "single_nat_gateway" {
  type        = bool
  description = "Use a single NAT Gateway across all AZs to optimize cost (set to false with one_nat_gateway_per_az for multi-AZ HA)"
  default     = true
}

variable "one_nat_gateway_per_az" {
  type        = bool
  description = "Deploy one NAT Gateway per AZ for maximum high availability"
  default     = false
}

# =============================================================================
# Section 4: Cross-Cloud HA VPN & BGP Dynamic Routing
# =============================================================================

variable "aws_bgp_asn" {
  type        = number
  description = "BGP Autonomous System Number (ASN) for AWS Virtual Private Gateway (must be a private ASN)"
  default     = 64512

  validation {
    condition     = (var.aws_bgp_asn >= 64512 && var.aws_bgp_asn <= 65534) || (var.aws_bgp_asn >= 4200000000 && var.aws_bgp_asn <= 4294967294)
    error_message = "aws_bgp_asn must be a valid private ASN (64512-65534 or 4200000000-4294967294)."
  }
}

variable "gcp_bgp_asn" {
  type        = number
  description = "BGP Autonomous System Number (ASN) for GCP Cloud Router (must be a private ASN different from aws_bgp_asn)"
  default     = 64514

  validation {
    condition     = (var.gcp_bgp_asn >= 64512 && var.gcp_bgp_asn <= 65534) || (var.gcp_bgp_asn >= 4200000000 && var.gcp_bgp_asn <= 4294967294)
    error_message = "gcp_bgp_asn must be a valid private ASN (64512-65534 or 4200000000-4294967294)."
  }
}

variable "bgp_advertised_route_priority" {
  type        = number
  description = "Base priority for routes advertised by GCP Cloud Router BGP peers to AWS VGW"
  default     = 100
}

variable "vpn_tunnel_inside_cidrs" {
  type        = map(string)
  description = "Inside /30 CIDR ranges for the 4 IPsec tunnels (must be within 169.254.0.0/16, excluding AWS reserved blocks)"
  default = {
    "0-1" = "169.254.10.0/30"
    "0-2" = "169.254.10.4/30"
    "1-1" = "169.254.11.0/30"
    "1-2" = "169.254.11.4/30"
  }
}

variable "vpn_ike_versions" {
  type        = list(string)
  description = "IKE protocol versions supported for the AWS VPN connections"
  default     = ["ikev2"]
}

# =============================================================================
# Section 5: AWS Storage Gateway Appliance & EC2 Host
# =============================================================================

variable "gateway_name" {
  type        = string
  description = "Name of the AWS Storage Gateway appliance"
  default     = "gcp-vm-file-gateway"
}

variable "gateway_instance_name" {
  type        = string
  description = "Name tag for the Storage Gateway EC2 host instance"
  default     = "gateway-instance"
}

variable "gateway_timezone" {
  type        = string
  description = "Timezone for the Storage Gateway appliance (e.g., GMT, America/New_York)"
  default     = "GMT"
}

variable "gateway_type" {
  type        = string
  description = "Type of Storage Gateway (FILE_S3)"
  default     = "FILE_S3"

  validation {
    condition     = contains(["FILE_S3", "VTL", "STORED", "CACHED"], var.gateway_type)
    error_message = "gateway_type must be one of: FILE_S3, VTL, STORED, CACHED."
  }
}

variable "gateway_instance_type" {
  type        = string
  description = "EC2 instance type for Storage Gateway (minimum m5.xlarge or m4.xlarge recommended by AWS)"
  default     = "m5.xlarge"
}

variable "key_name" {
  type        = string
  description = "Optional AWS EC2 Key Pair Name for the Storage Gateway instance"
  default     = null
}

variable "cache_disk_size" {
  type        = number
  description = "Size in GiB for the Storage Gateway local cache EBS volume (minimum 150 GiB required by AWS)"
  default     = 150

  validation {
    condition     = var.cache_disk_size >= 150
    error_message = "cache_disk_size must be at least 150 GiB as required by AWS Storage Gateway specifications."
  }
}

variable "cache_disk_type" {
  type        = string
  description = "EBS volume type for the gateway cache disk (gp3, gp2, io2)"
  default     = "gp3"
}

variable "cache_disk_device_name" {
  type        = string
  description = "Device name for attaching the cache EBS volume to the EC2 host"
  default     = "/dev/sdb"
}

variable "cache_disk_iops" {
  type        = number
  description = "Provisioned IOPS for gp3/io2 cache EBS volume"
  default     = 3000
}

variable "cache_disk_throughput" {
  type        = number
  description = "Provisioned throughput in MiB/s for gp3 cache EBS volume"
  default     = 125
}

variable "cache_disk_encrypted" {
  type        = bool
  description = "Enable encryption at rest for the Storage Gateway cache EBS volume"
  default     = true
}

variable "cache_disk_kms_key_arn" {
  type        = string
  description = "KMS Key ARN for cache volume encryption (uses default AWS EBS key if null)"
  default     = null
}

variable "activation_key" {
  type        = string
  description = "AWS Storage Gateway activation key (optional; if omitted, automatically fetched across the VPN from GCP client VM)"
  default     = null
  sensitive   = true
}

variable "gateway_instance_role_name" {
  type        = string
  description = "Name of the IAM role attached to the Storage Gateway EC2 host instance"
  default     = "storage-gateway-instance-role"
}

variable "gateway_instance_profile_name" {
  type        = string
  description = "Name of the IAM instance profile attached to the Storage Gateway EC2 host instance"
  default     = "storage-gateway-instance-profile"
}

variable "gateway_sg_name" {
  type        = string
  description = "Name of the security group for the Storage Gateway EC2 host"
  default     = "gateway-sg"
}

variable "vpce_sg_name" {
  type        = string
  description = "Name of the security group for the Storage Gateway Interface VPC Endpoint"
  default     = "storagegateway-vpce-sg"
}

# =============================================================================
# Section 6: Amazon S3 Bucket & Security (Storage Target)
# =============================================================================

variable "s3_bucket_name" {
  type        = string
  description = "Target Amazon S3 bucket name backing the Storage Gateway file share"
  default     = "gcp-simulated-storage-gateway-bucket"
}

variable "s3_force_destroy" {
  type        = bool
  description = "Allow bucket deletion when objects are present (keep false in production to prevent data loss)"
  default     = false
}

variable "s3_versioning_enabled" {
  type        = string
  description = "S3 Versioning configuration (Enabled, Suspended, Disabled)"
  default     = "Enabled"

  validation {
    condition     = contains(["Enabled", "Suspended", "Disabled"], var.s3_versioning_enabled)
    error_message = "s3_versioning_enabled must be one of: Enabled, Suspended, Disabled."
  }
}

variable "storage_gateway_role_name" {
  type        = string
  description = "Name of the IAM role assumed by the AWS Storage Gateway service to access S3"
  default     = "storage-gateway-role"
}

variable "enable_least_privilege_iam" {
  type        = bool
  description = "Attach a least-privilege IAM policy scoped strictly to the target S3 bucket instead of AmazonS3FullAccess"
  default     = true
}

# =============================================================================
# Section 7: SMB File Share Settings
# =============================================================================

variable "smb_guest_password" {
  type        = string
  description = "Password for SMB GuestAccess ('smbguest' user)"
  default     = "GuestPass123!"
  sensitive   = true
}

variable "smb_authentication" {
  type        = string
  description = "Authentication method for SMB file share (GuestAccess or ActiveDirectory)"
  default     = "GuestAccess"

  validation {
    condition     = contains(["GuestAccess", "ActiveDirectory"], var.smb_authentication)
    error_message = "smb_authentication must be either 'GuestAccess' or 'ActiveDirectory'."
  }
}

variable "smb_read_only" {
  type        = bool
  description = "Whether the SMB file share is read-only"
  default     = false
}

variable "smb_guess_mime_type" {
  type        = bool
  description = "Enable automatic MIME type guessing for files uploaded to S3 via SMB"
  default     = true
}

variable "smb_case_sensitivity" {
  type        = string
  description = "Case sensitivity behavior for SMB share (ClientSpecified or CaseSensitive)"
  default     = "ClientSpecified"

  validation {
    condition     = contains(["ClientSpecified", "CaseSensitive"], var.smb_case_sensitivity)
    error_message = "smb_case_sensitivity must be either 'ClientSpecified' or 'CaseSensitive'."
  }
}

variable "smb_file_share_name" {
  type        = string
  description = "Custom SMB share display name (defaults to target S3 bucket name if null)"
  default     = null
}

variable "smb_admin_users" {
  type        = list(string)
  description = "List of users with admin privileges on the SMB share"
  default     = []
}

variable "smb_valid_users" {
  type        = list(string)
  description = "List of users authorized to access the SMB share (empty list allows all authenticated/guest users)"
  default     = []
}

variable "smb_invalid_users" {
  type        = list(string)
  description = "List of users explicitly denied access to the SMB share"
  default     = []
}
