variable "name" {
  type        = string
  description = "Name tag for the VPC endpoint"
}

variable "vpc_id" {
  type        = string
  description = "The ID of the VPC in which the endpoint will be created"
}

variable "service_name" {
  type        = string
  description = "The service name, in the form com.amazonaws.<region>.<service>"
}

variable "vpc_endpoint_type" {
  type        = string
  description = "The VPC endpoint type: Interface, Gateway, or GatewayLoadBalancer"
  default     = "Interface"

  validation {
    condition     = contains(["Interface", "Gateway", "GatewayLoadBalancer"], var.vpc_endpoint_type)
    error_message = "vpc_endpoint_type must be one of: Interface, Gateway, GatewayLoadBalancer."
  }
}

variable "auto_accept" {
  type        = bool
  description = "Accept the VPC endpoint (PTFE/cross-account connection requests)"
  default     = null
}

variable "policy" {
  type        = string
  description = "A policy to attach to the endpoint that controls access to the service (JSON string)"
  default     = null
}

variable "private_dns_enabled" {
  type        = bool
  description = "Whether or not to associate a private hosted zone with the specified VPC (Interface endpoints only)"
  default     = false
}

variable "route_table_ids" {
  type        = list(string)
  description = "One or more route table IDs (Gateway endpoints only)"
  default     = null
}

variable "subnet_ids" {
  type        = list(string)
  description = "The ID of one or more subnets in which to create a network interface for the endpoint (Interface endpoints only)"
  default     = null
}

variable "security_group_ids" {
  type        = list(string)
  description = "The ID of one or more security groups to associate with the network interface (Interface endpoints only)"
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "A map of tags to assign to the resource"
  default     = {}
}
