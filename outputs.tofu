output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table for state locking"
  value       = aws_dynamodb_table.locks.arn
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table for state locking"
  value       = aws_dynamodb_table.locks.name
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket for OpenTofu state"
  value       = aws_s3_bucket.tfstate.arn
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for OpenTofu state"
  value       = aws_s3_bucket.tfstate.id
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for secrets encryption"
  value       = var.enable_kms_key ? aws_kms_key.secrets[0].arn : null
}

output "kms_key_alias" {
  description = "Alias of the KMS key used for secrets encryption"
  value       = var.enable_kms_key ? aws_kms_alias.secrets_alias[0].name : null
}
