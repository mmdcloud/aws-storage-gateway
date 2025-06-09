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
      name          = "source-vpc-firewall"
      source_ranges = [module.instance2.network_ip]
      allow_list = [
        {
          protocol = "icmp"
          ports    = []
        }
      ]
    },
    {
      name          = "vpc1-firewall-ssh"
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

resource "google_compute_address" "source_vm_ip" {
  name = "instance1-address"
}

# Instance 1
module "source_vm" {
  source                    = "./modules/compute"
  name                      = "source-vm"
  machine_type              = "e2-micro"
  zone                      = "us-central1-a"
  metadata_startup_script   = "sudo apt-get update; sudo apt-get install nginx -y"
  deletion_protection       = false
  allow_stopping_for_update = true
  image                     = "ubuntu-os-cloud/ubuntu-2004-focal-v20220712"
  network_interfaces = [
    {
      network    = module.vpc1.vpc_id
      subnetwork = module.vpc1.subnets[0].id
      access_configs = [
        {
          nat_ip = google_compute_address.instance1_ip.address
        }
      ]
    }
  ]
}