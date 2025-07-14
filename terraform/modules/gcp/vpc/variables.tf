variable "vpc_name" {}
variable "delete_default_routes_on_create" {}
variable "auto_create_subnetworks" {}
variable "routing_mode" {}
variable "ip_cidr_ranges" {
  type = list(string)
}
variable "region" {}
variable "private_ip_google_access" {}
variable "firewall_data" {
  type = list(object({
    name          = string
    source_ranges = set(string)
    allow_list = set(object({
      protocol = string
      ports    = list(string)
    }))
  }))
}