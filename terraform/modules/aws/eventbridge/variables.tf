variable "rule_name" {
  type        = string
  description = "The name of the EventBridge rule"
}

variable "rule_description" {
  type        = string
  description = "The description of the EventBridge rule"
  default     = null
}

variable "event_pattern" {
  type        = string
  description = "The event pattern described as a JSON object"
}

variable "target_arn" {
  type        = string
  description = "The Amazon Resource Name (ARN) of the target resource"
}

variable "target_id" {
  type        = string
  description = "The unique target assignment ID"
  default     = "default"
}

variable "tags" {
  type        = map(string)
  description = "A mapping of tags to assign to the rule"
  default     = {}
}
