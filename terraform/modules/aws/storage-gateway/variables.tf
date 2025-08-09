variable "gateway_name" {}
variable "gateway_timezone" {}
variable "gateway_type" {}
variable "gateway_ip_address" {}
variable "nfs_shares" {
  type = list(object({
    client_list             = list(string)
    location_arn            = string
    role_arn                = string
    default_storage_class   = string
    guess_mime_type_enabled = string
    requester_pays          = string
    squash                  = string
  }))
  default = []
}

variable "smb_shares" {
  type = list(object({
    location_arn            = string
    role_arn                = string
    authentication          = string
    guess_mime_type_enabled = bool
    read_only               = bool
    valid_user_list         = list(string)
    smb_acl_enabled         = bool
  }))
}
