# Create the Storage Gateway
resource "aws_storagegateway_gateway" "file_gateway" {
  gateway_name       = var.gateway_name
  gateway_timezone   = var.gateway_timezone
  gateway_type       = var.gateway_type
  gateway_ip_address = var.gateway_ip_address
}

# Create the Storage Gateway File Share
resource "aws_storagegateway_nfs_file_share" "file_share" {
  count                   = length(var.nfs_shares)
  gateway_arn             = aws_storagegateway_gateway.file_gateway.arn
  client_list             = var.nfs_shares[count.index].client_list
  location_arn            = var.nfs_shares[count.index].location_arn
  role_arn                = var.nfs_shares[count.index].role_arn
  default_storage_class   = var.nfs_shares[count.index].default_storage_class
  guess_mime_type_enabled = var.nfs_shares[count.index].guess_mime_type_enabled
  requester_pays          = var.nfs_shares[count.index].requester_pays
  squash                  = var.nfs_shares[count.index].squash
}

resource "aws_storagegateway_smb_file_share" "smb_share" {
  count                   = length(var.smb_shares)
  gateway_arn             = aws_storagegateway_gateway.file_gateway.arn
  location_arn            = var.smb_shares[count.index].location_arn
  role_arn                = var.smb_shares[count.index].role_arn
  authentication          = var.smb_shares[count.index].authentication
  guess_mime_type_enabled = var.smb_shares[count.index].guess_mime_type_enabled
  read_only               = var.smb_shares[count.index].read_only
  valid_user_list         = var.smb_shares[count.index].valid_user_list
  smb_acl_enabled         = var.smb_shares[count.index].smb_acl_enabled
}