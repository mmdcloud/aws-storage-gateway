variable "name" {
  type        = string
  description = "Name tag of the EC2 instance"
}

variable "ami_id" {
  type        = string
  description = "AMI ID for the instance"
}

variable "instance_type" {
  type        = string
  description = "Instance type"
}

variable "key_name" {
  type        = string
  description = "Key pair name"
  default     = null
}

variable "associate_public_ip_address" {
  type        = bool
  description = "Whether to associate a public IP"
  default     = true
}

variable "user_data" {
  type        = string
  description = "User data script"
  default     = null
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID"
}

variable "security_groups" {
  type        = list(string)
  description = "List of security group IDs"
}

variable "instance_profile" {
  type        = string
  description = "IAM instance profile name"
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Tags to attach to the instance"
  default     = {}
}
