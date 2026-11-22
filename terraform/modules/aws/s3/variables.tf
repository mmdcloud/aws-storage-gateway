variable "bucket_name" {}
variable "force_destroy" {}
variable "versioning_enabled" {}
variable "objects" {
  type = list(object({
    source = string
    key    = string
  }))
  default = []
}
variable "cors" {
  type = list(object({
    allowed_headers = list(string)
    allowed_methods = list(string)
    allowed_origins = list(string)
    max_age_seconds = number
  }))
  default = []
}
variable "bucket_policy" {
  type    = string
  default = ""
}
variable "tags" {
  type        = map(string)
  description = "Tags to assign to the bucket"
  default     = {}
}
variable "bucket_notification" {
  type = object({
    queue = list(object({
      queue_arn = string
      events    = list(string)
    }))
    lambda_function = list(object({
      lambda_function_arn = string
      events              = list(string)
    }))
  })
  default = {
    queue           = []
    lambda_function = []
  }
}
variable "enable_eventbridge" {
  type        = bool
  description = "Whether to enable Amazon EventBridge notifications for the S3 bucket"
  default     = false
}

variable "kms_key_arn" {
  type        = string
  description = "KMS master key ARN for S3 server-side encryption. If null, AES256 (SSE-S3) is used"
  default     = null
}

variable "enable_lifecycle_rules" {
  type        = bool
  description = "Enable lifecycle rules for multipart upload abort and noncurrent version management"
  default     = true
}

variable "noncurrent_version_expiration_days" {
  type        = number
  description = "Number of days before noncurrent object versions expire in S3"
  default     = 90
}