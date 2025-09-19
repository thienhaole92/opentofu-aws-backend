variable "project" {
  type        = string
  description = "Project name used for resource naming and tagging"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "region" {
  type        = string
  description = "AWS region where resources will be deployed"
  default     = "ap-southeast-1"

  validation {
    condition     = contains(["ap-southeast-1"], var.region)
    error_message = "Region must be one of the supported AWS regions."
  }
}

variable "group" {
  type        = string
  description = "Environment group: nonprod (dev/uat) or prod (production)"

  validation {
    condition     = contains(["nonprod", "prod"], var.group)
    error_message = "Group must be either 'nonprod' or 'prod'."
  }
}

variable "transition_ia_days" {
  type        = number
  description = "Number of days before moving non-current versions to STANDARD_IA storage class"
  default     = 30

  validation {
    condition     = var.transition_ia_days >= 0
    error_message = "Transition days must be a non-negative number."
  }
}

variable "transition_glacier_days" {
  type        = number
  description = "Number of days before moving non-current versions to GLACIER storage class"
  default     = 60

  validation {
    condition     = var.transition_glacier_days >= 0
    error_message = "Transition days must be a non-negative number."
  }
}

variable "expiration_days" {
  type        = number
  description = "Number of days before expiring non-current versions"
  default     = 90

  validation {
    condition     = var.expiration_days >= 0
    error_message = "Expiration days must be a non-negative number."
  }
}

variable "enable_lifecycle_policies" {
  type        = bool
  description = "Whether to enable S3 bucket lifecycle policies"
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Additional tags to apply to all resources"
  default     = {}
}
