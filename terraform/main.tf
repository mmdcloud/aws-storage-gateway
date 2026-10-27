# -----------------------------------------------------------------------------
# Tunnel topology
# -----------------------------------------------------------------------------
locals {
  vpn_tunnels = {
    "0-1" = { conn = "0", aws_tunnel = 1, gcp_interface = 0, peer_interface = 0 }
    "0-2" = { conn = "0", aws_tunnel = 2, gcp_interface = 0, peer_interface = 1 }
    "1-1" = { conn = "1", aws_tunnel = 1, gcp_interface = 1, peer_interface = 2 }
    "1-2" = { conn = "1", aws_tunnel = 2, gcp_interface = 1, peer_interface = 3 }
  }

  aws_vpn_connections = {
    "0" = aws_vpn_connection.vpn_conn_0
    "1" = aws_vpn_connection.vpn_conn_1
  }
}

# One PSK per tunnel. AWS rejects PSKs starting with "0", so prefix with a letter.
resource "random_password" "psk" {
  for_each = local.vpn_tunnels
  length   = 32
  special  = false
}

locals {
  psk = { for k, v in random_password.psk : k => "vpn_${v.result}" }
}

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
      source_ranges = ["10.0.0.0/16", "10.10.1.0/24"]
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
    },
    {
      name          = "allow-icmp"
      source_ranges = ["10.0.0.0/16", "10.10.1.0/24"]
      allow_list = [
        {
          protocol = "icmp"
          ports    = []
        }
      ]
    }
  ]
}

resource "google_compute_router" "router" {
  name    = "cr-ha-vpn"
  region  = var.gcp_region
  network = module.gcp_vpc.vpc_id

  bgp {
    asn               = 64514
    advertise_mode    = "CUSTOM"
    advertised_groups = ["ALL_SUBNETS"]
  }
}

resource "google_compute_ha_vpn_gateway" "ha_gateway" {
  name    = "gcp-ha-vpn-gw"
  region  = var.gcp_region
  network = module.gcp_vpc.vpc_id
}

resource "aws_vpn_gateway" "vpn_gw" {
  vpc_id          = module.vpc.vpc_id
  amazon_side_asn = 64512

  tags = {
    Name = "aws-vgw-gcp"
  }
}

resource "aws_vpn_gateway_route_propagation" "private" {
  count          = length(module.vpc.private_route_table_ids)
  vpn_gateway_id = aws_vpn_gateway.vpn_gw.id
  route_table_id = module.vpc.private_route_table_ids[count.index]
}

resource "aws_customer_gateway" "gcp_cgw_0" {
  bgp_asn    = google_compute_router.router.bgp[0].asn
  ip_address = google_compute_ha_vpn_gateway.ha_gateway.vpn_interfaces[0].ip_address
  type       = "ipsec.1"

  tags = {
    Name = "gcp-customer-gw-0"
  }
}

resource "aws_customer_gateway" "gcp_cgw_1" {
  bgp_asn    = google_compute_router.router.bgp[0].asn
  ip_address = google_compute_ha_vpn_gateway.ha_gateway.vpn_interfaces[1].ip_address
  type       = "ipsec.1"

  tags = {
    Name = "gcp-customer-gw-1"
  }
}

# Inside CIDRs must be /30s in 169.254.0.0/16 and must avoid the AWS-reserved
# blocks (169.254.0.0/30 - 169.254.5.0/30, 169.254.169.252/30). In each /30,
# .1 is the AWS VGW and .2 is the GCP Cloud Router interface.
resource "aws_vpn_connection" "vpn_conn_0" {
  vpn_gateway_id      = aws_vpn_gateway.vpn_gw.id
  customer_gateway_id = aws_customer_gateway.gcp_cgw_0.id
  type                = "ipsec.1"
  static_routes_only  = false

  tunnel1_inside_cidr   = "169.254.10.0/30"
  tunnel1_preshared_key = local.psk["0-1"]
  tunnel1_ike_versions  = ["ikev2"]

  tunnel2_inside_cidr   = "169.254.10.4/30"
  tunnel2_preshared_key = local.psk["0-2"]
  tunnel2_ike_versions  = ["ikev2"]

  tags = {
    Name = "aws-to-gcp-conn-0"
  }
}

resource "aws_vpn_connection" "vpn_conn_1" {
  vpn_gateway_id      = aws_vpn_gateway.vpn_gw.id
  customer_gateway_id = aws_customer_gateway.gcp_cgw_1.id
  type                = "ipsec.1"
  static_routes_only  = false

  tunnel1_inside_cidr   = "169.254.11.0/30"
  tunnel1_preshared_key = local.psk["1-1"]
  tunnel1_ike_versions  = ["ikev2"]

  tunnel2_inside_cidr   = "169.254.11.4/30"
  tunnel2_preshared_key = local.psk["1-2"]
  tunnel2_ike_versions  = ["ikev2"]

  tags = {
    Name = "aws-to-gcp-conn-1"
  }
}

# -----------------------------------------------------------------------------
# GCP side of the VPN: external gateway, 4 tunnels, router interfaces, BGP peers
# -----------------------------------------------------------------------------
resource "google_compute_external_vpn_gateway" "external_gw" {
  name            = "peer-gw"
  redundancy_type = "FOUR_IPS_REDUNDANCY"

  interface {
    id         = 0
    ip_address = aws_vpn_connection.vpn_conn_0.tunnel1_address
  }

  interface {
    id         = 1
    ip_address = aws_vpn_connection.vpn_conn_0.tunnel2_address
  }

  interface {
    id         = 2
    ip_address = aws_vpn_connection.vpn_conn_1.tunnel1_address
  }

  interface {
    id         = 3
    ip_address = aws_vpn_connection.vpn_conn_1.tunnel2_address
  }
}

resource "google_compute_vpn_tunnel" "tunnel" {
  for_each = local.vpn_tunnels

  name                            = "ha-vpn-tunnel-${each.key}"
  region                          = var.gcp_region
  vpn_gateway                     = google_compute_ha_vpn_gateway.ha_gateway.id
  vpn_gateway_interface           = each.value.gcp_interface
  peer_external_gateway           = google_compute_external_vpn_gateway.external_gw.id
  peer_external_gateway_interface = each.value.peer_interface
  shared_secret                   = local.psk[each.key]
  router                          = google_compute_router.router.id
  ike_version                     = 2
}

resource "google_compute_router_interface" "interface" {
  for_each = local.vpn_tunnels

  name       = "cr-interface-${each.key}"
  router     = google_compute_router.router.name
  region     = var.gcp_region
  ip_range   = "${local.aws_vpn_connections[each.value.conn]["tunnel${each.value.aws_tunnel}_cgw_inside_address"]}/30"
  vpn_tunnel = google_compute_vpn_tunnel.tunnel[each.key].name
}

resource "google_compute_router_peer" "bgp_peer" {
  for_each = local.vpn_tunnels

  name                      = "bgp-peer-${each.key}"
  router                    = google_compute_router.router.name
  region                    = var.gcp_region
  peer_ip_address           = local.aws_vpn_connections[each.value.conn]["tunnel${each.value.aws_tunnel}_vgw_inside_address"]
  peer_asn                  = aws_vpn_gateway.vpn_gw.amazon_side_asn
  interface                 = google_compute_router_interface.interface[each.key].name
  advertised_route_priority = 100
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
  map_public_ip_on_launch = false
  enable_nat_gateway      = true
  single_nat_gateway      = false
  one_nat_gateway_per_az  = true
  tags = {
    Name = "vpc"
  }
}

# Security Group for Storage Gateway VPC Endpoint
resource "aws_security_group" "storagegateway_vpce" {
  name        = "storagegateway-vpce-sg"
  description = "Security group for AWS Storage Gateway Interface VPC Endpoint"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTPS traffic for Storage Gateway activation and management"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = concat([module.vpc.vpc_cidr_block], var.source_vpc_ip_cidr_range)
  }

  ingress {
    description = "Storage Gateway service communication ports 1026-1031"
    from_port   = 1026
    to_port     = 1031
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  ingress {
    description = "Storage Gateway service communication port 2222"
    from_port   = 2222
    to_port     = 2222
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "storagegateway-vpce-sg"
  }
}

# Interface VPC Endpoint for Storage Gateway
resource "aws_vpc_endpoint" "storagegateway" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.storagegateway"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.storagegateway_vpce.id]
  private_dns_enabled = true

  tags = {
    Name = "storagegateway-interface-endpoint"
  }
}

# Non-zonal DNS name of the Storage Gateway VPC endpoint (dns_entry order is not guaranteed,
# and the zonal names like vpce-xxx-us-east-1a.* are not valid for activation).
locals {
  sgw_vpce_dns = [
    for e in aws_vpc_endpoint.storagegateway.dns_entry : e.dns_name
    if !can(regex("-${var.aws_region}[a-z]\\.", e.dns_name))
  ][0]
}

# Gateway VPC Endpoint for Amazon S3
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc.private_route_table_ids

  tags = {
    Name = "s3-gateway-endpoint"
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
      cidr_blocks     = concat([module.vpc.vpc_cidr_block], var.source_vpc_ip_cidr_range)
      security_groups = []
      description     = "HTTP traffic for Storage Gateway activation"
    },
    {
      from_port       = 443
      to_port         = 443
      protocol        = "tcp"
      self            = "false"
      cidr_blocks     = concat([module.vpc.vpc_cidr_block], var.source_vpc_ip_cidr_range)
      security_groups = []
      description     = "HTTPS traffic for Storage Gateway activation and management"
    },
    {
      from_port       = 445
      to_port         = 445
      protocol        = "tcp"
      self            = "false"
      cidr_blocks     = concat([module.vpc.vpc_cidr_block], var.source_vpc_ip_cidr_range)
      security_groups = []
      description     = "SMB traffic for file shares"
    },
    {
      from_port       = 139
      to_port         = 139
      protocol        = "tcp"
      self            = "false"
      cidr_blocks     = concat([module.vpc.vpc_cidr_block], var.source_vpc_ip_cidr_range)
      security_groups = []
      description     = "NetBIOS session service for SMB"
    },
    {
      from_port       = 22
      to_port         = 22
      protocol        = "tcp"
      self            = "false"
      cidr_blocks     = concat([module.vpc.vpc_cidr_block], var.source_vpc_ip_cidr_range)
      security_groups = []
      description     = "SSH access for gateway administration"
    },
    {
      from_port       = -1
      to_port         = -1
      protocol        = "icmp"
      self            = "false"
      cidr_blocks     = concat([module.vpc.vpc_cidr_block], var.source_vpc_ip_cidr_range)
      security_groups = []
      description     = "ICMP traffic for ping connectivity testing"
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

# Storage Gateway EC2 Host Instance (Deployed in Private Subnet, no public IP)
module "gateway_instance" {
  source                      = "./modules/aws/ec2"
  name                        = "gateway-instance"
  ami_id                      = data.aws_ssm_parameter.storage_gateway_ami.value
  instance_type               = var.gateway_instance_type
  key_name                    = var.key_name
  associate_public_ip_address = false
  instance_profile            = aws_iam_instance_profile.iam_instance_profile.name
  subnet_id                   = module.vpc.private_subnets[0]
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

# Automatically retrieve Storage Gateway activation key across the HA VPN from GCP source-vm
data "external" "activation_key" {
  count   = var.activation_key == null ? 1 : 0
  program = ["python3", "${path.module}/scripts/get_activation_key.py"]

  query = {
    gateway_ip   = module.gateway_instance.private_ip
    region       = var.aws_region
    vpc_endpoint = local.sgw_vpce_dns
    vm_name      = "source-vm"
    zone         = "${var.gcp_region}-a"
    project      = var.gcp_project
  }

  depends_on = [
    module.source_vm,
    module.gateway_instance,
    aws_vpn_connection.vpn_conn_0,
    aws_vpn_connection.vpn_conn_1,
    google_compute_router_peer.bgp_peer,
    aws_vpc_endpoint.storagegateway
  ]
}

locals {
  gateway_activation_key = var.activation_key != null ? var.activation_key : (
    length(data.external.activation_key) > 0 ? data.external.activation_key[0].result["activation_key"] : null
  )
}

# Storage Gateway & SMB File Share (Configured with Private IP & Private VPC Endpoint)
module "storage_gateway" {
  source               = "./modules/aws/storage-gateway"
  gateway_name         = "gcp-vm-file-gateway"
  gateway_timezone     = "GMT"
  gateway_type         = "FILE_S3"
  gateway_ip_address   = module.gateway_instance.private_ip
  gateway_vpc_endpoint = local.sgw_vpce_dns
  activation_key       = local.gateway_activation_key
  smb_guest_password   = var.smb_guest_password
  cache_disk_node      = aws_volume_attachment.gateway_cache_attachment.device_name
  smb_shares = [
    {
      location_arn            = module.s3_bucket.arn
      role_arn                = aws_iam_role.storage_gateway_role.arn
      authentication          = "GuestAccess"
      guess_mime_type_enabled = true
      read_only               = false
    }
  ]

  depends_on = [
    aws_vpc_endpoint.storagegateway,
    aws_vpc_endpoint.s3
  ]
}