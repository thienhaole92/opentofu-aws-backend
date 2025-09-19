terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.13.0"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = merge({
      Project     = var.project
      Environment = var.group
      Terraform   = "true"
      ManagedBy   = "terraform"
    }, var.tags)
  }
}

locals {
  bucket_name = "${var.project}-${var.group}-terraform-backend"
  table_name  = "${var.project}-${var.group}-terraform-state-locks"

  common_tags = {
    Project     = var.project
    Environment = var.group
    Terraform   = "true"
    ManagedBy   = "terraform"
  }
}

resource "aws_s3_bucket" "tfstate" {
  bucket = local.bucket_name

  tags = merge(local.common_tags, {
    Name = "terraform-backend"
  })
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
      sse_algorithm = "AES256"
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

# Enable bucket lifecycle configuration to manage old versions
resource "aws_s3_bucket_lifecycle_configuration" "tfstate" {
  bucket     = aws_s3_bucket.tfstate.id
  depends_on = [aws_s3_bucket_versioning.tfstate]

  dynamic "rule" {
    for_each = var.enable_lifecycle_policies ? [1] : []

    content {
      id     = "state-version-lifecycle"
      status = "Enabled"

      # Filter block applies to all objects in bucket
      filter {}

      noncurrent_version_transition {
        noncurrent_days = var.transition_ia_days
        storage_class   = "STANDARD_IA"
      }

      noncurrent_version_transition {
        noncurrent_days = var.transition_glacier_days
        storage_class   = "GLACIER"
      }

      noncurrent_version_expiration {
        noncurrent_days = var.expiration_days
      }
    }
  }
}

# Add bucket policy to enforce encryption and secure access
resource "aws_s3_bucket_policy" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.tfstate.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "AES256"
          }
        }
      },
      {
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.tfstate.arn}/*"
        Condition = {
          Null = {
            "s3:x-amz-server-side-encryption" = true
          }
        }
      }
    ]
  })
}

# ----------------------------
# DynamoDB Table for State Locking
# ----------------------------
resource "aws_dynamodb_table" "locks" {
  name         = local.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  server_side_encryption {
    enabled = true
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = merge(local.common_tags, {
    Name = "terraform-state-locks"
  })
}
