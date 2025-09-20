variable "project" {
  type        = string
  description = "Project name used for resource naming and tagging."

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "region" {
  type        = string
  description = "AWS region where resources will be deployed."
  default     = "ap-southeast-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z-]+-[0-9]$", var.region))
    error_message = "Region must be a valid AWS region identifier (e.g., 'us-east-1')."
  }
}

variable "group" {
  type        = string
  description = "Environment group: nonprod (dev/uat) or prod (production)."

  validation {
    condition     = contains(["nonprod", "prod"], var.group)
    error_message = "Group must be either 'nonprod' or 'prod'."
  }
}

variable "tags" {
  type        = map(string)
  description = "Additional custom tags to apply to all resources."
  default     = {}

  validation {
    condition     = alltrue([for k, v in var.tags : can(regex("^[a-zA-Z0-9][a-zA-Z0-9-_]{0,127}$", k))])
    error_message = "Tag keys must be 1-128 characters, starting with a letter or number, and can include letters, numbers, hyphens, and underscores."
  }
}

variable "enable_lifecycle_policy" {
  type        = bool
  description = "Enable S3 bucket lifecycle policy for cost optimization."
  default     = true
}

variable "noncurrent_version_expiration_days" {
  type        = number
  description = "Days to retain non-current S3 object versions before deletion."
  default     = 90

  validation {
    condition     = var.noncurrent_version_expiration_days >= 30 && var.noncurrent_version_expiration_days <= 365
    error_message = "Non-current version expiration must be between 30 and 365 days."
  }
}

variable "enable_dynamodb_pitr" {
  type        = bool
  description = "Enable Point-in-Time Recovery for DynamoDB table."
  default     = true
}

variable "enable_kms_key" {
  type        = bool
  description = "Enable creation of KMS key for secrets encryption."
  default     = true
}

variable "kms_deletion_window" {
  type        = number
  description = "Number of days before a deleted KMS key is permanently removed."
  default     = 30

  validation {
    condition     = var.kms_deletion_window >= 7 && var.kms_deletion_window <= 30
    error_message = "KMS deletion window must be between 7 and 30 days."
  }
}
