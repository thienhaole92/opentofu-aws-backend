terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.13"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = merge({
      Project     = var.project
      Environment = var.group
      ManagedBy   = "OpenTofu"
    }, var.tags)
  }
}

locals {
  name_prefix = "${var.project}-${var.group}"
  bucket_name = "${local.name_prefix}-tfstate-${var.region}"
}

# -----------------------------------------------------------------------------
# S3 BUCKET FOR TERRAFORM STATE
# -----------------------------------------------------------------------------

resource "aws_s3_bucket" "tfstate" {
  bucket = local.bucket_name

  # Prevent accidental deletion
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Purpose = "OpenTofu state storage"
  }
}

# Enable versioning (important for recovering old states)
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enforce server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.enable_kms_key ? "aws:kms" : "AES256"
      kms_master_key_id = var.enable_kms_key ? aws_kms_key.secrets[0].arn : null
    }
  }
}

# Block all forms of public access
resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# This policy enforces encryption in transit (HTTPS).
resource "aws_s3_bucket_policy" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  policy = data.aws_iam_policy_document.tfstate.json
}

data "aws_iam_policy_document" "tfstate" {
  statement {
    sid    = "EnforceTLSTrafficOnly"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.tfstate.arn,
      "${aws_s3_bucket.tfstate.arn}/*",
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

# Enable bucket lifecycle configuration to manage old versions
resource "aws_s3_bucket_lifecycle_configuration" "tfstate" {
  count  = var.enable_lifecycle_policy ? 1 : 0
  bucket = aws_s3_bucket.tfstate.id

  rule {
    id     = "state-lifecycle"
    status = "Enabled"

    filter {} # Apply to all objects

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# -----------------------------------------------------------------------------
# DYNAMODB TABLE FOR STATE LOCKING
# -----------------------------------------------------------------------------

resource "aws_dynamodb_table" "locks" {
  name         = "${local.name_prefix}-state-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  # TTL automatically cleans up stale locks.
  ttl {
    attribute_name = "Expires"
    enabled        = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.enable_kms_key ? aws_kms_key.secrets[0].arn : null
  }

  point_in_time_recovery {
    enabled = var.enable_dynamodb_pitr
  }

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Purpose = "OpenTofu state locking"
  }
}

# -----------------------------------------------------------------------------
# KMS KEY FOR SECRETS ENCRYPTION
# -----------------------------------------------------------------------------

resource "aws_kms_key" "secrets" {
  count                   = var.enable_kms_key ? 1 : 0
  description             = "KMS key for encrypting OpenTofu state and credentials in ${var.group}"
  deletion_window_in_days = var.kms_deletion_window
  enable_key_rotation     = true

  tags = {
    Name    = "${local.name_prefix}-secrets"
    Purpose = "OpenTofu state encryption"
  }
}

resource "aws_kms_alias" "secrets_alias" {
  count         = var.enable_kms_key ? 1 : 0
  name          = "alias/${local.name_prefix}-secrets"
  target_key_id = aws_kms_key.secrets[0].key_id
}
