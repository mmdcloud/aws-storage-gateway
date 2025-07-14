# Create the Storage Gateway
resource "aws_storagegateway_gateway" "file_gateway" {
  gateway_name     = var.gateway_name
  gateway_timezone = var.gateway_timezone
  gateway_type     = var.gateway_type
  gateway_ip_address = var.gateway_ip_address
}

# Create the Storage Gateway File Share
resource "aws_storagegateway_nfs_file_share" "gcp_share" {
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
