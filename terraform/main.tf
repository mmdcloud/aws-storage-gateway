# -----------------------------------------------------------------------------------------
# GCP Configuration
# -----------------------------------------------------------------------------------------

# Source VPC 
module "source_vpc" {
  source                          = "./modules/gcp/vpc"
  vpc_name                        = "source-vpc"
  delete_default_routes_on_create = false
  auto_create_subnetworks         = false
  routing_mode                    = "REGIONAL"
  ip_cidr_ranges                  = var.ip_cidr_range1
  region                          = var.region
  private_ip_google_access        = false
  firewall_data = [
    {
      name          = "allow-smb"
      source_ranges = ["0.0.0.0/0"]
      allow_list = [
        {
          protocol = "tcp"
          ports    = ["445"]
        }
      ]
    }
  ]
}

resource "google_compute_address" "source_vm_ip" {
  name = "source-vm-address"
}

# Instance 1
module "source_vm" {
  source                    = "./modules/gcp/compute"
  name                      = "source-vm"
  machine_type              = "e2-micro"
  zone                      = "us-central1-a"
  metadata_startup_script   = "sudo apt-get update; sudo apt-get install nginx -y"
  deletion_protection       = false
  allow_stopping_for_update = true
  image                     = "ubuntu-os-cloud/ubuntu-2004-focal-v20220712"
  network_interfaces = [
    {
      network    = module.source_vpc.vpc_id
      subnetwork = module.source_vpc.subnets[0].id
      access_configs = [
        {
          nat_ip = google_compute_address.source_vm_ip.address
        }
      ]
    }
  ]
}

# -----------------------------------------------------------------------------------------
# AWS Configuration
# -----------------------------------------------------------------------------------------

module "vpc" {
  source                = "./modules/vpc/vpc"
  vpc_name              = "vpc"
  vpc_cidr_block        = "10.0.0.0/16"
  enable_dns_hostnames  = true
  enable_dns_support    = true
  internet_gateway_name = "vpc_igw"
}

# Security Group
module "sg" {
  source = "./modules/aws/vpc/security_groups"
  vpc_id = module.vpc.vpc_id
  name   = "sg"
  ingress = [
    {
      from_port       = 80
      to_port         = 80
      protocol        = "tcp"
      self            = "false"
      cidr_blocks     = ["0.0.0.0/0"]
      security_groups = []
      description     = "HTTP traffic"
    },
    {
      from_port       = 443
      to_port         = 443
      protocol        = "tcp"
      self            = "false"
      cidr_blocks     = ["0.0.0.0/0"]
      security_groups = []
      description     = "HTTPS traffic"
    }
  ]
  egress = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

# Public Subnets
module "public_subnets" {
  source = "./modules/vpc/subnets"
  name   = "public subnet"
  subnets = [
    {
      subnet = "10.0.1.0/24"
      az     = "${var.region}a"
    },
    {
      subnet = "10.0.2.0/24"
      az     = "${var.region}b"
    },
    {
      subnet = "10.0.3.0/24"
      az     = "${var.region}c"
    }
  ]
  vpc_id                  = module.vpc.vpc_id
  map_public_ip_on_launch = true
}

# Private Subnets
module "private_subnets" {
  source = "./modules/vpc/subnets"
  name   = "private subnet"
  subnets = [
    {
      subnet = "10.0.6.0/24"
      az     = "${var.region}a"
    },
    {
      subnet = "10.0.5.0/24"
      az     = "${var.region}b"
    },
    {
      subnet = "10.0.4.0/24"
      az     = "${var.region}c"
    }
  ]
  vpc_id                  = module.vpc.vpc_id
  map_public_ip_on_launch = false
}

# Public Route Table
module "public_rt" {
  source  = "./modules/vpc/route_tables"
  name    = "public route table"
  subnets = module.public_subnets.subnets[*]
  routes = [
    {
      cidr_block     = "0.0.0.0/0"
      gateway_id     = module.vpc.igw_id
      nat_gateway_id = ""
    }
  ]
  vpc_id = module.vpc.vpc_id
}

# Private Route Table
module "private_rt" {
  source  = "./modules/vpc/route_tables"
  name    = "private route table"
  subnets = module.private_subnets.subnets[*]
  routes  = []
  vpc_id  = module.vpc.vpc_id
}

# Create an IAM role for Storage Gateway
resource "aws_iam_role" "storage_gateway_role" {
  name = "storage-gateway-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "storagegateway.amazonaws.com"
        }
      }
    ]
  })
}

# Attach policy to the IAM role
resource "aws_iam_role_policy_attachment" "storage_gateway_policy" {
  role       = aws_iam_role.storage_gateway_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

module "s3_bucket" {
  source      = "./modules/s3"
  bucket_name = "storage-gateway-file-share"
  objects = []
  bucket_policy = ""
  cors = [
    {
      allowed_headers = ["*"]
      allowed_methods = ["GET"]
      allowed_origins = ["*"]
      max_age_seconds = 3000
    }
  ]
  versioning_enabled = "Enabled"
  force_destroy      = true
}