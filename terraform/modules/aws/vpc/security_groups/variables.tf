variable "name" {
  type        = string
  description = "Name of the security group"
}

variable "description" {
  type        = string
  description = "Description of the security group"
  default     = "Security group managed by Terraform"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where the security group is created"
}

variable "ingress" {
  type        = any
  description = "List of ingress rules"
  default     = []
}

variable "egress" {
  type        = any
  description = "List of egress rules"
  default     = []
}

