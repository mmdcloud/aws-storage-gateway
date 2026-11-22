variable "function_name" {
  type        = string
  description = "Name of the Lambda function"
}

variable "role_arn" {
  type        = string
  description = "IAM role ARN attached to the Lambda Function"
}

variable "handler" {
  type        = string
  description = "Function entrypoint in your code"
  default     = "index.handler"
}

variable "runtime" {
  type        = string
  description = "Identifier of the function's runtime"
  default     = "python3.11"
}

variable "filename" {
  type        = string
  description = "Path to the function's deployment package within the local filesystem"
  default     = null
}

variable "source_code_hash" {
  type        = string
  description = "Used to trigger updates when local zip changes (base64sha256)"
  default     = null
}

variable "s3_bucket" {
  type        = string
  description = "S3 bucket location containing the function's deployment package"
  default     = null
}

variable "s3_key" {
  type        = string
  description = "S3 key of an object containing the function's deployment package"
  default     = null
}

variable "timeout" {
  type        = number
  description = "Amount of time your Lambda Function has to run in seconds"
  default     = 30
}

variable "memory_size" {
  type        = number
  description = "Amount of memory in MB your Lambda Function can use at runtime"
  default     = 128
}

variable "code_signing_config_arn" {
  type        = string
  description = "Code signing configuration ARN"
  default     = null
}

variable "layers" {
  type        = list(string)
  description = "List of Lambda Layer Version ARNs to attach to your Lambda Function"
  default     = []
}

variable "env_variables" {
  type        = map(string)
  description = "Map of environment variables that are accessible from the function code"
  default     = {}
}

variable "permissions" {
  type = list(object({
    statement_id = string
    action       = string
    principal    = string
    source_arn   = string
  }))
  description = "List of permissions to grant to the Lambda function"
  default     = []
}

variable "tags" {
  type        = map(string)
  description = "Tags to attach to the Lambda function"
  default     = {}
}

variable "vpc_config" {
  type = object({
    security_group_ids = set(string)
    subnet_ids         = set(string)
  })
  description = "VPC configuration for the Lambda function"
  default     = null
}

variable "dead_letter_config" {
  type = object({
    target_arn = string
  })
  description = "Dead letter configuration for the Lambda function"
  default     = null
}
