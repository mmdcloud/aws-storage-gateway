# -----------------------------------------------------------------------------------------
# GCP Configuration (Simulated On-Premise Environment)
# -----------------------------------------------------------------------------------------

# On-Prem VPC (Simulated)
module "gcp_vpc" {
  source                          = "./modules/gcp/vpc"
  vpc_name                        = "source-vpc"
  delete_default_routes_on_create = false
  auto_create_subnetworks         = false
  routing_mode                    = "REGIONAL"
  ip_cidr_ranges                  = var.source_vpc_ip_cidr_range
  region                          = var.gcp_region
  private_ip_google_access        = false
  firewall_data = [
    {
      name          = "allow-smb"
      source_ranges = ["0.0.0.0/0"]
      allow_list = [
        {
          protocol = "tcp"
          ports    = ["445", "139"]
        }
      ]
    },
    {
      name          = "allow-ssh"
      source_ranges = ["0.0.0.0/0"]
      allow_list = [
        {
          protocol = "tcp"
          ports    = ["22"]
        }
      ]
    }
  ]
}

# Static External IP for GCP VM
resource "google_compute_address" "source_vm_ip" {
  name   = "source-vm-address"
  region = var.gcp_region
}

# Simulated On-Premise VM (running Samba & SMB client tools)
module "source_vm" {
  source                    = "./modules/gcp/compute"
  name                      = "source-vm"
  machine_type              = "e2-medium"
  zone                      = "${var.gcp_region}-a"
  metadata_startup_script   = file("${path.module}/scripts/user_data.sh")
  deletion_protection       = false
  allow_stopping_for_update = true
  image                     = "ubuntu-os-cloud/ubuntu-2004-focal-v20220712"
  network_interfaces = [
    {
      network    = module.gcp_vpc.vpc_id
      subnetwork = module.gcp_vpc.subnets[0].id
      access_configs = [
        {
          nat_ip = google_compute_address.source_vm_ip.address
        }
      ]
    }
  ]
}

# -----------------------------------------------------------------------------------------
# AWS Configuration (Storage Gateway & S3)
# -----------------------------------------------------------------------------------------

# AWS VPC
module "vpc" {
  source                  = "./modules/aws/vpc"
  vpc_name                = "vpc"
  vpc_cidr                = "10.0.0.0/16"
  azs                     = var.azs
  public_subnets          = var.public_subnets
  private_subnets         = var.private_subnets
  database_subnets        = var.database_subnets
  enable_dns_hostnames    = true
  enable_dns_support      = true
  create_igw              = true
  map_public_ip_on_launch = true
  enable_nat_gateway      = true
  single_nat_gateway      = false
  one_nat_gateway_per_az  = true
  tags = {
    Name = "vpc"
  }
}

# Security Group for Storage Gateway Host
module "gateway_sg" {
  source = "./modules/aws/vpc/security_groups"
  vpc_id = module.vpc.vpc_id
  name   = "gateway-sg"
  ingress = [
    {
      from_port       = 80
      to_port         = 80
      protocol        = "tcp"
      self            = "false"
      cidr_blocks     = ["0.0.0.0/0"]
      security_groups = []
      description     = "HTTP traffic for Storage Gateway activation"
    },
    {
      from_port       = 443
      to_port         = 443
      protocol        = "tcp"
      self            = "false"
      cidr_blocks     = ["0.0.0.0/0"]
      security_groups = []
      description     = "HTTPS traffic for Storage Gateway activation and management"
    },
    {
      from_port       = 445
      to_port         = 445
      protocol        = "tcp"
      self            = "false"
      cidr_blocks     = ["0.0.0.0/0"]
      security_groups = []
      description     = "SMB traffic for file shares"
    },
    {
      from_port       = 139
      to_port         = 139
      protocol        = "tcp"
      self            = "false"
      cidr_blocks     = ["0.0.0.0/0"]
      security_groups = []
      description     = "NetBIOS session service for SMB"
    },
    {
      from_port       = 22
      to_port         = 22
      protocol        = "tcp"
      self            = "false"
      cidr_blocks     = ["0.0.0.0/0"]
      security_groups = []
      description     = "SSH access for gateway administration"
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

# Dynamic AMI for AWS Storage Gateway (File Gateway)
data "aws_ssm_parameter" "storage_gateway_ami" {
  name = "/aws/service/storagegateway/ami/FILE_S3/latest"
}

# IAM Role & Instance Profile for EC2 Gateway Host
resource "aws_iam_role" "gateway_instance_role" {
  name = "storage-gateway-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "gateway_instance_ssm" {
  role       = aws_iam_role.gateway_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "iam_instance_profile" {
  name = "storage-gateway-instance-profile"
  role = aws_iam_role.gateway_instance_role.name
}

# Storage Gateway EC2 Host Instance
module "gateway_instance" {
  source                      = "./modules/aws/ec2"
  name                        = "gateway-instance"
  ami_id                      = data.aws_ssm_parameter.storage_gateway_ami.value
  instance_type               = var.gateway_instance_type
  key_name                    = var.key_name
  associate_public_ip_address = true
  instance_profile            = aws_iam_instance_profile.iam_instance_profile.name
  subnet_id                   = module.vpc.public_subnets[0]
  security_groups             = [module.gateway_sg.id]
}

# EBS Volume for Storage Gateway Local Cache (Required by Storage Gateway before creating shares)
resource "aws_ebs_volume" "gateway_cache" {
  availability_zone = var.azs[0]
  size              = 150
  type              = "gp3"

  tags = {
    Name = "storage-gateway-cache-disk"
  }
}

resource "aws_volume_attachment" "gateway_cache_attachment" {
  device_name  = "/dev/sdb"
  volume_id    = aws_ebs_volume.gateway_cache.id
  instance_id  = module.gateway_instance.id
  force_detach = true
}

# IAM Role for Storage Gateway Service to access S3
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

# S3 Bucket backed by Storage Gateway
module "s3_bucket" {
  source        = "./modules/aws/s3"
  bucket_name   = var.s3_bucket_name
  objects       = []
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

# Storage Gateway & SMB File Share
module "storage_gateway" {
  source             = "./modules/aws/storage-gateway"
  gateway_name       = "gcp-vm-file-gateway"
  gateway_timezone   = "GMT"
  gateway_type       = "FILE_S3"
  gateway_ip_address = module.gateway_instance.public_ip
  smb_guest_password = var.smb_guest_password
  cache_disk_node    = aws_volume_attachment.gateway_cache_attachment.device_name
  smb_shares = [
    {
      location_arn            = module.s3_bucket.arn
      role_arn                = aws_iam_role.storage_gateway_role.arn
      authentication          = "GuestAccess"
      guess_mime_type_enabled = true
      read_only               = false
    }
  ]
}