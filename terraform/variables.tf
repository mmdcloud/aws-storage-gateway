variable "gcp_region" {
  type    = string
  default = "us-central1"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "source_vpc_ip_cidr_range" {
  type    = list(string)
  default = ["10.1.0.0/16"]
}
