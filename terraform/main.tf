# =============================================================================
# Production-Grade AWS Storage Gateway over HA VPN with VPC Endpoints
# =============================================================================

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  gcp_zone    = var.gcp_zone != null ? var.gcp_zone : "${var.gcp_region}-a"

  # Standard common tags applied consistently to all AWS resources
  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.tags
  )

  # Dynamic tunnel mapping for the 4 IPsec tunnels connecting AWS VGW to GCP Cloud Router
  vpn_tunnels = {
    "0-1" = { conn = "0", aws_tunnel = 1, gcp_interface = 0, peer_interface = 0, inside_cidr = var.vpn_tunnel_inside_cidrs["0-1"] }
    "0-2" = { conn = "0", aws_tunnel = 2, gcp_interface = 0, peer_interface = 1, inside_cidr = var.vpn_tunnel_inside_cidrs["0-2"] }
    "1-1" = { conn = "1", aws_tunnel = 1, gcp_interface = 1, peer_interface = 2, inside_cidr = var.vpn_tunnel_inside_cidrs["1-1"] }
    "1-2" = { conn = "1", aws_tunnel = 2, gcp_interface = 1, peer_interface = 3, inside_cidr = var.vpn_tunnel_inside_cidrs["1-2"] }
  }

  aws_vpn_connections = {
    "0" = aws_vpn_connection.vpn_conn_0
    "1" = aws_vpn_connection.vpn_conn_1
  }
}

# Secure, randomly generated Pre-Shared Keys (PSK) for each IPsec tunnel
# AWS rejects PSKs starting with "0", so prefix with "vpn_"
resource "random_password" "psk" {
  for_each = local.vpn_tunnels
  length   = 32
  special  = false
}

locals {
  psk = { for k, v in random_password.psk : k => "vpn_${v.result}" }
}

# =============================================================================
# GCP Configuration (Simulated On-Premise Environment)
# =============================================================================

# On-Prem VPC Network (Simulated)
module "gcp_vpc" {
  source                          = "./modules/gcp/vpc"
  vpc_name                        = var.gcp_vpc_name
  delete_default_routes_on_create = false
  auto_create_subnetworks         = false
  routing_mode                    = "REGIONAL"
  ip_cidr_ranges                  = var.source_vpc_ip_cidr_range
  region                          = var.gcp_region
  private_ip_google_access        = false
  firewall_data = [
    {
      name          = "allow-smb"
      source_ranges = concat([var.aws_vpc_cidr], var.source_vpc_ip_cidr_range)
      allow_list = [
        {
          protocol = "tcp"
          ports    = ["445", "139"]
        }
      ]
    },
    {
      name          = "allow-ssh"
      source_ranges = var.gcp_allowed_ssh_cidrs
      allow_list = [
        {
          protocol = "tcp"
          ports    = ["22"]
        }
      ]
    },
    {
      name          = "allow-icmp"
      source_ranges = concat([var.aws_vpc_cidr], var.source_vpc_ip_cidr_range)
      allow_list = [
        {
          protocol = "icmp"
          ports    = []
        }
      ]
    }
  ]
}

# GCP Cloud Router for BGP Dynamic Routing
resource "google_compute_router" "router" {
  name    = var.gcp_router_name
  region  = var.gcp_region
  network = module.gcp_vpc.vpc_id

  bgp {
    asn               = var.gcp_bgp_asn
    advertise_mode    = "CUSTOM"
    advertised_groups = ["ALL_SUBNETS"]
  }
}

# GCP High Availability (HA) VPN Gateway
resource "google_compute_ha_vpn_gateway" "ha_gateway" {
  name    = var.gcp_ha_vpn_gw_name
  region  = var.gcp_region
  network = module.gcp_vpc.vpc_id
}

# AWS Virtual Private Gateway (VGW)
resource "aws_vpn_gateway" "vpn_gw" {
  vpc_id          = module.vpc.vpc_id
  amazon_side_asn = var.aws_bgp_asn

  tags = merge(
    local.common_tags,
    {
      Name = "aws-vgw-gcp"
    }
  )
}

# Propagate BGP Dynamic Routes from VGW into Private Route Tables
resource "aws_vpn_gateway_route_propagation" "private" {
  count          = length(module.vpc.private_route_table_ids)
  vpn_gateway_id = aws_vpn_gateway.vpn_gw.id
  route_table_id = module.vpc.private_route_table_ids[count.index]
}

# AWS Customer Gateways (CGWs) pointing to the 2 interfaces of GCP HA VPN Gateway
resource "aws_customer_gateway" "gcp_cgw_0" {
  bgp_asn    = google_compute_router.router.bgp[0].asn
  ip_address = google_compute_ha_vpn_gateway.ha_gateway.vpn_interfaces[0].ip_address
  type       = "ipsec.1"

  tags = merge(
    local.common_tags,
    {
      Name = "gcp-customer-gw-0"
    }
  )
}

resource "aws_customer_gateway" "gcp_cgw_1" {
  bgp_asn    = google_compute_router.router.bgp[0].asn
  ip_address = google_compute_ha_vpn_gateway.ha_gateway.vpn_interfaces[1].ip_address
  type       = "ipsec.1"

  tags = merge(
    local.common_tags,
    {
      Name = "gcp-customer-gw-1"
    }
  )
}

# AWS Site-to-Site VPN Connections with BGP Dynamic Routing
resource "aws_vpn_connection" "vpn_conn_0" {
  vpn_gateway_id      = aws_vpn_gateway.vpn_gw.id
  customer_gateway_id = aws_customer_gateway.gcp_cgw_0.id
  type                = "ipsec.1"
  static_routes_only  = false

  tunnel1_inside_cidr   = var.vpn_tunnel_inside_cidrs["0-1"]
  tunnel1_preshared_key = local.psk["0-1"]
  tunnel1_ike_versions  = var.vpn_ike_versions

  tunnel2_inside_cidr   = var.vpn_tunnel_inside_cidrs["0-2"]
  tunnel2_preshared_key = local.psk["0-2"]
  tunnel2_ike_versions  = var.vpn_ike_versions

  tags = merge(
    local.common_tags,
    {
      Name = "aws-to-gcp-conn-0"
    }
  )
}

resource "aws_vpn_connection" "vpn_conn_1" {
  vpn_gateway_id      = aws_vpn_gateway.vpn_gw.id
  customer_gateway_id = aws_customer_gateway.gcp_cgw_1.id
  type                = "ipsec.1"
  static_routes_only  = false

  tunnel1_inside_cidr   = var.vpn_tunnel_inside_cidrs["1-1"]
  tunnel1_preshared_key = local.psk["1-1"]
  tunnel1_ike_versions  = var.vpn_ike_versions

  tunnel2_inside_cidr   = var.vpn_tunnel_inside_cidrs["1-2"]
  tunnel2_preshared_key = local.psk["1-2"]
  tunnel2_ike_versions  = var.vpn_ike_versions

  tags = merge(
    local.common_tags,
    {
      Name = "aws-to-gcp-conn-1"
    }
  )
}

# GCP External VPN Gateway representing the 4 AWS VPN tunnel endpoints
resource "google_compute_external_vpn_gateway" "external_gw" {
  name            = var.gcp_external_vpn_gw_name
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

# GCP HA VPN Tunnels
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

# GCP Cloud Router Interfaces for BGP Peering
resource "google_compute_router_interface" "interface" {
  for_each = local.vpn_tunnels

  name       = "cr-interface-${each.key}"
  router     = google_compute_router.router.name
  region     = var.gcp_region
  ip_range   = "${local.aws_vpn_connections[each.value.conn]["tunnel${each.value.aws_tunnel}_cgw_inside_address"]}/30"
  vpn_tunnel = google_compute_vpn_tunnel.tunnel[each.key].name
}

# GCP Cloud Router BGP Peers
resource "google_compute_router_peer" "bgp_peer" {
  for_each = local.vpn_tunnels

  name                      = "bgp-peer-${each.key}"
  router                    = google_compute_router.router.name
  region                    = var.gcp_region
  peer_ip_address           = local.aws_vpn_connections[each.value.conn]["tunnel${each.value.aws_tunnel}_vgw_inside_address"]
  peer_asn                  = aws_vpn_gateway.vpn_gw.amazon_side_asn
  interface                 = google_compute_router_interface.interface[each.key].name
  advertised_route_priority = var.bgp_advertised_route_priority
}

# Static Public IP for GCP Client VM
resource "google_compute_address" "source_vm_ip" {
  name   = var.gcp_vm_ip_name
  region = var.gcp_region
}

# Simulated On-Premise Client VM (running Samba & SMB client tools)
module "source_vm" {
  source                    = "./modules/gcp/compute"
  name                      = var.gcp_vm_name
  machine_type              = var.gcp_vm_machine_type
  zone                      = local.gcp_zone
  metadata_startup_script   = file("${path.module}/scripts/user_data.sh")
  deletion_protection       = var.gcp_vm_deletion_protection
  allow_stopping_for_update = true
  image                     = var.gcp_vm_image
  labels                    = var.gcp_labels
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

# =============================================================================
# AWS Configuration (VPC, Storage Gateway, VPC Endpoints & S3)
# =============================================================================

# AWS VPC
module "vpc" {
  source                  = "./modules/aws/vpc"
  vpc_name                = var.aws_vpc_name
  vpc_cidr                = var.aws_vpc_cidr
  azs                     = var.azs
  public_subnets          = var.public_subnets
  private_subnets         = var.private_subnets
  database_subnets        = var.database_subnets
  enable_dns_hostnames    = true
  enable_dns_support      = true
  create_igw              = true
  map_public_ip_on_launch = false
  enable_nat_gateway      = var.enable_nat_gateway
  single_nat_gateway      = var.single_nat_gateway
  one_nat_gateway_per_az  = var.one_nat_gateway_per_az
  tags = merge(
    local.common_tags,
    {
      Name = var.aws_vpc_name
    }
  )
}

# Security Group for Storage Gateway Interface VPC Endpoint
resource "aws_security_group" "storagegateway_vpce" {
  name        = var.vpce_sg_name
  description = "Security group for AWS Storage Gateway Interface VPC Endpoint"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTPS traffic for Storage Gateway activation and management"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = concat([var.aws_vpc_cidr], var.source_vpc_ip_cidr_range)
  }

  ingress {
    description = "Storage Gateway service communication ports 1026-1031"
    from_port   = 1026
    to_port     = 1031
    protocol    = "tcp"
    cidr_blocks = [var.aws_vpc_cidr]
  }

  ingress {
    description = "Storage Gateway service communication port 2222"
    from_port   = 2222
    to_port     = 2222
    protocol    = "tcp"
    cidr_blocks = [var.aws_vpc_cidr]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = var.vpce_sg_name
    }
  )
}

# Interface VPC Endpoint for AWS Storage Gateway (PrivateLink Control Plane)
resource "aws_vpc_endpoint" "storagegateway" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.storagegateway"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.storagegateway_vpce.id]
  private_dns_enabled = true

  tags = merge(
    local.common_tags,
    {
      Name = "storagegateway-interface-endpoint"
    }
  )
}

# Extract regional non-zonal DNS name of the Storage Gateway VPC Endpoint
locals {
  sgw_vpce_dns = [
    for e in aws_vpc_endpoint.storagegateway.dns_entry : e.dns_name
    if !can(regex("-${var.aws_region}[a-z]\\.", e.dns_name))
  ][0]
}

# Gateway VPC Endpoint for Amazon S3 (Private Data Plane Route)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc.private_route_table_ids

  tags = merge(
    local.common_tags,
    {
      Name = "s3-gateway-endpoint"
    }
  )
}

# Security Group for Storage Gateway EC2 Host
module "gateway_sg" {
  source = "./modules/aws/vpc/security_groups"
  vpc_id = module.vpc.vpc_id
  name   = var.gateway_sg_name
  tags   = local.common_tags
  ingress = [
    {
      from_port       = 80
      to_port         = 80
      protocol        = "tcp"
      self            = "false"
      cidr_blocks     = concat([var.aws_vpc_cidr], var.source_vpc_ip_cidr_range)
      security_groups = []
      description     = "HTTP traffic for Storage Gateway activation"
    },
    {
      from_port       = 443
      to_port         = 443
      protocol        = "tcp"
      self            = "false"
      cidr_blocks     = concat([var.aws_vpc_cidr], var.source_vpc_ip_cidr_range)
      security_groups = []
      description     = "HTTPS traffic for Storage Gateway activation and management"
    },
    {
      from_port       = 445
      to_port         = 445
      protocol        = "tcp"
      self            = "false"
      cidr_blocks     = concat([var.aws_vpc_cidr], var.source_vpc_ip_cidr_range)
      security_groups = []
      description     = "SMB traffic for file shares"
    },
    {
      from_port       = 139
      to_port         = 139
      protocol        = "tcp"
      self            = "false"
      cidr_blocks     = concat([var.aws_vpc_cidr], var.source_vpc_ip_cidr_range)
      security_groups = []
      description     = "NetBIOS session service for SMB"
    },
    {
      from_port       = 22
      to_port         = 22
      protocol        = "tcp"
      self            = "false"
      cidr_blocks     = concat([var.aws_vpc_cidr], var.source_vpc_ip_cidr_range)
      security_groups = []
      description     = "SSH access for gateway administration"
    },
    {
      from_port       = -1
      to_port         = -1
      protocol        = "icmp"
      self            = "false"
      cidr_blocks     = concat([var.aws_vpc_cidr], var.source_vpc_ip_cidr_range)
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
  name = "/aws/service/storagegateway/ami/${var.gateway_type}/latest"
}

# IAM Role & Instance Profile for EC2 Gateway Host
resource "aws_iam_role" "gateway_instance_role" {
  name = var.gateway_instance_role_name

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

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "gateway_instance_ssm" {
  role       = aws_iam_role.gateway_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "iam_instance_profile" {
  name = var.gateway_instance_profile_name
  role = aws_iam_role.gateway_instance_role.name
}

# Storage Gateway EC2 Host Instance (Deployed in Private Subnet, no public IP)
module "gateway_instance" {
  source                      = "./modules/aws/ec2"
  name                        = var.gateway_instance_name
  ami_id                      = data.aws_ssm_parameter.storage_gateway_ami.value
  instance_type               = var.gateway_instance_type
  key_name                    = var.key_name
  associate_public_ip_address = false
  instance_profile            = aws_iam_instance_profile.iam_instance_profile.name
  subnet_id                   = module.vpc.private_subnets[0]
  security_groups             = [module.gateway_sg.id]
  tags                        = local.common_tags
}

# EBS Volume for Storage Gateway Local Cache (Min 150 GiB required by AWS)
resource "aws_ebs_volume" "gateway_cache" {
  availability_zone = var.azs[0]
  size              = var.cache_disk_size
  type              = var.cache_disk_type
  iops              = var.cache_disk_type == "gp3" ? var.cache_disk_iops : null
  throughput        = var.cache_disk_type == "gp3" ? var.cache_disk_throughput : null
  encrypted         = var.cache_disk_encrypted
  kms_key_id        = var.cache_disk_kms_key_arn

  tags = merge(
    local.common_tags,
    {
      Name = "storage-gateway-cache-disk"
    }
  )
}

resource "aws_volume_attachment" "gateway_cache_attachment" {
  device_name  = var.cache_disk_device_name
  volume_id    = aws_ebs_volume.gateway_cache.id
  instance_id  = module.gateway_instance.id
  force_detach = true
}

# IAM Role for Storage Gateway Service to access S3
resource "aws_iam_role" "storage_gateway_role" {
  name = var.storage_gateway_role_name

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

  tags = local.common_tags
}

# Least-Privilege IAM Policy for Storage Gateway S3 Access (Production Best Practice)
data "aws_iam_policy_document" "storage_gateway_s3_least_privilege" {
  statement {
    sid    = "S3BucketAccess"
    effect = "Allow"
    actions = [
      "s3:GetAccelerateConfiguration",
      "s3:GetBucketLocation",
      "s3:GetBucketVersioning",
      "s3:ListBucket",
      "s3:ListBucketVersions",
      "s3:ListBucketMultipartUploads"
    ]
    resources = [module.s3_bucket.arn]
  }

  statement {
    sid    = "S3ObjectAccess"
    effect = "Allow"
    actions = [
      "s3:AbortMultipartUpload",
      "s3:DeleteObject",
      "s3:DeleteObjectVersion",
      "s3:GetObject",
      "s3:GetObjectAcl",
      "s3:GetObjectVersion",
      "s3:ListMultipartUploadParts",
      "s3:PutObject",
      "s3:PutObjectAcl"
    ]
    resources = ["${module.s3_bucket.arn}/*"]
  }
}

resource "aws_iam_policy" "storage_gateway_s3_policy" {
  count       = var.enable_least_privilege_iam ? 1 : 0
  name        = "${var.storage_gateway_role_name}-s3-policy"
  description = "Least-privilege policy for AWS Storage Gateway to access bucket ${var.s3_bucket_name}"
  policy      = data.aws_iam_policy_document.storage_gateway_s3_least_privilege.json
  tags        = local.common_tags
}

resource "aws_iam_role_policy_attachment" "storage_gateway_policy" {
  role       = aws_iam_role.storage_gateway_role.name
  policy_arn = var.enable_least_privilege_iam ? aws_iam_policy.storage_gateway_s3_policy[0].arn : "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# S3 Bucket backed by Storage Gateway
module "s3_bucket" {
  source             = "./modules/aws/s3"
  bucket_name        = var.s3_bucket_name
  objects            = []
  bucket_policy      = ""
  cors               = [
    {
      allowed_headers = ["*"]
      allowed_methods = ["GET"]
      allowed_origins = ["*"]
      max_age_seconds = 3000
    }
  ]
  versioning_enabled = var.s3_versioning_enabled
  force_destroy      = var.s3_force_destroy
  tags               = local.common_tags
}

# Automatically retrieve Storage Gateway activation key across the HA VPN from GCP source-vm
data "external" "activation_key" {
  count   = var.activation_key == null ? 1 : 0
  program = ["python3", "${path.module}/scripts/get_activation_key.py"]

  query = {
    gateway_ip   = module.gateway_instance.private_ip
    region       = var.aws_region
    vpc_endpoint = local.sgw_vpce_dns
    vm_name      = var.gcp_vm_name
    zone         = local.gcp_zone
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
  gateway_name         = var.gateway_name
  gateway_timezone     = var.gateway_timezone
  gateway_type         = var.gateway_type
  gateway_ip_address   = module.gateway_instance.private_ip
  gateway_vpc_endpoint = local.sgw_vpce_dns
  activation_key       = local.gateway_activation_key
  smb_guest_password   = var.smb_guest_password
  cache_disk_node      = aws_volume_attachment.gateway_cache_attachment.device_name
  tags                 = local.common_tags
  smb_shares = [
    {
      location_arn            = module.s3_bucket.arn
      role_arn                = aws_iam_role.storage_gateway_role.arn
      authentication          = var.smb_authentication
      guess_mime_type_enabled = var.smb_guess_mime_type
      read_only               = var.smb_read_only
      case_sensitivity        = var.smb_case_sensitivity
      file_share_name         = var.smb_file_share_name != null ? var.smb_file_share_name : var.s3_bucket_name
      admin_user_list         = length(var.smb_admin_users) > 0 ? var.smb_admin_users : null
      valid_user_list         = length(var.smb_valid_users) > 0 ? var.smb_valid_users : null
      invalid_user_list       = length(var.smb_invalid_users) > 0 ? var.smb_invalid_users : null
    }
  ]

  depends_on = [
    aws_vpc_endpoint.storagegateway,
    aws_vpc_endpoint.s3
  ]
}
