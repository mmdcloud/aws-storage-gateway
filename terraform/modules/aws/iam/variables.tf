variable "role_name" {
  type        = string
  description = "The name of the IAM role"
}

variable "role_description" {
  type        = string
  description = "The description of the IAM role"
  default     = null
}

variable "assume_role_policy" {
  type        = string
  description = "The policy that grants an entity permission to assume the role (JSON string)"
}

variable "policy_name" {
  type        = string
  description = "The name of the custom IAM policy to create and attach"
  default     = null
}

variable "policy_description" {
  type        = string
  description = "The description of the custom IAM policy"
  default     = null
}

variable "policy" {
  type        = string
  description = "The policy document (JSON string) for a custom IAM policy. Leave null or empty string if no custom policy is needed"
  default     = null
}

variable "managed_policy_arns" {
  type        = list(string)
  description = "List of existing managed policy ARNs to attach to the role"
  default     = []
}

variable "tags" {
  type        = map(string)
  description = "A map of tags to assign to the role"
  default     = {}
}
