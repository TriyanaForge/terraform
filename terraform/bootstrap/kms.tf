resource "aws_kms_key" "terraform_primary_bucket_key" {
  description             = "KMS key for Terraform State"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = {
    Environment = var.environment
    Project     = var.project
    Purpose     = "terraform-state"
  }
}

resource "aws_kms_alias" "terraform_primary_bucket_key" {
  name          = "alias/terraform-primary-bucket-key-01"
  target_key_id = aws_kms_key.terraform_primary_bucket_key.id
}