variable "name" {
  type        = string
  description = "Friendly name of the new secret"
}

variable "description" {
  type        = string
  description = "Description of the secret"
  default     = null
}

variable "recovery_window_in_days" {
  type        = number
  description = "Number of days that AWS Secrets Manager waits before it can delete the secret (0 for force deletion, up to 30)"
  default     = 0
}

variable "secret_string" {
  type        = string
  description = "Specifies text data that you want to encrypt and store in this version of the secret"
  sensitive   = true
}

variable "replica" {
  description = "A set of replica configurations for the secret"
  type = set(object({
    region     = string
    kms_key_id = optional(string)
  }))
  default = []
}

variable "tags" {
  type        = map(string)
  description = "A mapping of tags to assign to the secret"
  default     = {}
}
