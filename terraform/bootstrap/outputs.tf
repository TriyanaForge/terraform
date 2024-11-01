# terraform/bootstrap/outputs.tf
output "state_bucket_name" {
  value = aws_s3_bucket.terraform_state_primary.id
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.terraform_primary_lock.name
}

output "kms_key_id" {
  value = aws_kms_key.terraform_primary_bucket_key.id
}