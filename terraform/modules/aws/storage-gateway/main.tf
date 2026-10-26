# Create the Storage Gateway
resource "aws_storagegateway_gateway" "file_gateway" {
  gateway_name         = var.gateway_name
  gateway_timezone     = var.gateway_timezone
  gateway_type         = var.gateway_type
  gateway_ip_address   = var.gateway_ip_address
  gateway_vpc_endpoint = var.gateway_vpc_endpoint
  smb_guest_password   = var.smb_guest_password
}

# Delay to allow Storage Gateway to discover newly attached EBS cache volumes
resource "time_sleep" "wait_for_cache_disk" {
  count           = var.cache_disk_node != null || var.cache_disk_path != null ? 1 : 0
  create_duration = "30s"

  depends_on = [aws_storagegateway_gateway.file_gateway]
}

# Local disk data source for cache (queries either disk_node or disk_path)
data "aws_storagegateway_local_disk" "cache" {
  count       = var.cache_disk_node != null || var.cache_disk_path != null ? 1 : 0
  gateway_arn = aws_storagegateway_gateway.file_gateway.arn
  disk_node   = var.cache_disk_node
  disk_path   = var.cache_disk_path

  depends_on = [time_sleep.wait_for_cache_disk]
}

# Configure the cache
resource "aws_storagegateway_cache" "file_gateway_cache" {
  count       = var.cache_disk_node != null || var.cache_disk_path != null ? 1 : 0
  gateway_arn = aws_storagegateway_gateway.file_gateway.arn
  disk_id     = data.aws_storagegateway_local_disk.cache[0].disk_id
}

# Create the Storage Gateway NFS File Share
resource "aws_storagegateway_nfs_file_share" "file_share" {
  count                   = length(var.nfs_shares)
  gateway_arn             = aws_storagegateway_gateway.file_gateway.arn
  client_list             = var.nfs_shares[count.index].client_list
  location_arn            = var.nfs_shares[count.index].location_arn
  role_arn                = var.nfs_shares[count.index].role_arn
  default_storage_class   = lookup(var.nfs_shares[count.index], "default_storage_class", "S3_STANDARD")
  guess_mime_type_enabled = lookup(var.nfs_shares[count.index], "guess_mime_type_enabled", true)
  requester_pays          = lookup(var.nfs_shares[count.index], "requester_pays", false)
  squash                  = lookup(var.nfs_shares[count.index], "squash", "RootSquash")

  depends_on = [aws_storagegateway_cache.file_gateway_cache]
}

# Create the Storage Gateway SMB File Share
resource "aws_storagegateway_smb_file_share" "smb_share" {
  count                   = length(var.smb_shares)
  gateway_arn             = aws_storagegateway_gateway.file_gateway.arn
  location_arn            = var.smb_shares[count.index].location_arn
  role_arn                = var.smb_shares[count.index].role_arn
  authentication          = lookup(var.smb_shares[count.index], "authentication", "GuestAccess")
  guess_mime_type_enabled = lookup(var.smb_shares[count.index], "guess_mime_type_enabled", true)
  read_only               = lookup(var.smb_shares[count.index], "read_only", false)
  valid_user_list         = lookup(var.smb_shares[count.index], "valid_user_list", null)
  smb_acl_enabled         = lookup(var.smb_shares[count.index], "smb_acl_enabled", null)

  depends_on = [aws_storagegateway_cache.file_gateway_cache]
}
