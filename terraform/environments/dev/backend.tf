terraform {
  backend "s3" {
    bucket         = "tf-dev-ap-south-1-tf-state-bucket"    # matches var.resource_prefix-${var.environment}-${var.primary_region}-tf-state-bucket-01
    key            = "env/dev/terraform.tfstate"               # path in bucket
    region         = "ap-south-1"                             # primary_region
    encrypt        = true
    kms_key_id     = "alias/terraform-primary-bucket-key-01"     # KMS key alias
    dynamodb_table = "tf-dev-tf-state-lock"               # DynamoDB table name
  }
}