resource "google_compute_network" "vpc" {
  name                            = var.vpc_name
  delete_default_routes_on_create = var.delete_default_routes_on_create
  auto_create_subnetworks         = var.auto_create_subnetworks
  routing_mode                    = var.routing_mode
}

resource "google_compute_subnetwork" "subnets" {
  count                    = length(var.ip_cidr_ranges)
  name                     = "${var.vpc_name}-subnet-${count.index + 1}"
  ip_cidr_range            = var.ip_cidr_ranges[count.index]
  region                   = var.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = var.private_ip_google_access
}

resource "google_compute_firewall" "firewall" {
  count   = length(var.firewall_data)
  name    = var.firewall_data[count.index].name
  network = google_compute_network.vpc.id
  dynamic "allow" {
    for_each = var.firewall_data[count.index].allow_list
    content {
      protocol = allow.value["protocol"]
      ports    = allow.value["ports"]
    }
  }

  source_ranges = var.firewall_data[count.index].source_ranges
}