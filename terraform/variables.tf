variable "gcp_region" {
  type    = string
}

variable "aws_region" {
  type    = string
}

variable "public_subnets" {
  type        = list(string)
  description = "Public Subnet CIDR values"
}

variable "private_subnets" {
  type        = list(string)
  description = "Private Subnet CIDR values"
}

variable "database_subnets" {
  type        = list(string)
  description = "Database Subnet CIDR values"
}

variable "azs" {
  type        = list(string)
  description = "Availability Zones"
}

variable "source_vpc_ip_cidr_range" {
  type    = list(string)
  default = ["10.0.1.0/24"]
}