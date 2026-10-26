variable "gateway_name" {
  type        = string
  description = "Name of the storage gateway"
}

variable "gateway_timezone" {
  type        = string
  description = "Timezone for the storage gateway (e.g. GMT)"
}

variable "gateway_type" {
  type        = string
  description = "Type of the gateway (e.g. FILE_S3)"
}

variable "gateway_ip_address" {
  type        = string
  description = "IP address of the gateway EC2 instance"
}

variable "gateway_vpc_endpoint" {
  type        = string
  description = "The VPC endpoint address that the gateway will connect to"
  default     = null
}

variable "smb_guest_password" {
  type        = string
  description = "Guest password for SMB file shares"
  default     = null
  sensitive   = true
}

variable "cache_disk_node" {
  type        = string
  description = "Device node for the gateway cache disk (e.g. /dev/sdb from volume attachment)"
  default     = null
}

variable "cache_disk_path" {
  type        = string
  description = "Local device path for the gateway cache disk (e.g. /dev/nvme1n1 or /dev/xvdb)"
  default     = null
}

variable "nfs_shares" {
  type    = any
  default = []
}

variable "smb_shares" {
  type    = any
  default = []
}
