variable "gcp_region" {
  type        = string
  description = "GCP Region for the simulated on-premise environment"
  default     = "us-central1"
}

variable "gcp_project" {
  type        = string
  description = "GCP Project ID"
  default     = "encoded-alpha-457108-e8"
}

variable "aws_region" {
  type        = string
  description = "AWS Region for Storage Gateway and VPC"
  default     = "us-east-1"
}

variable "public_subnets" {
  type        = list(string)
  description = "AWS Public Subnet CIDR values"
}

variable "private_subnets" {
  type        = list(string)
  description = "AWS Private Subnet CIDR values"
}

variable "database_subnets" {
  type        = list(string)
  description = "AWS Database Subnet CIDR values"
  default     = []
}

variable "azs" {
  type        = list(string)
  description = "AWS Availability Zones"
}

variable "source_vpc_ip_cidr_range" {
  type        = list(string)
  description = "GCP VPC Subnet CIDR ranges (simulated on-premise)"
  default     = ["10.10.1.0/24"]
}

variable "key_name" {
  type        = string
  description = "AWS EC2 Key Pair Name"
  default     = null
}

variable "gateway_instance_type" {
  type        = string
  description = "EC2 Instance type for Storage Gateway (minimum m5.xlarge or m4.xlarge recommended by AWS)"
  default     = "m5.xlarge"
}

variable "s3_bucket_name" {
  type        = string
  description = "Name of the S3 bucket for Storage Gateway file share"
  default     = "gcp-aws-storage-gateway-bucket"
}

variable "smb_guest_password" {
  type        = string
  description = "Password for SMB GuestAccess"
  default     = "GuestPass123!"
  sensitive   = true
}

variable "activation_key" {
  type        = string
  description = "AWS Storage Gateway activation key (optional; if omitted, automatically retrieved across the HA VPN from the on-premise GCP VM)"
  default     = null
}
