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
}
