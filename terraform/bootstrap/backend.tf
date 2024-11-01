# terraform/bootstrap/backend.tf
terraform {
  backend "s3" {
    bucket         = "triyanaforge-backend"
    key            = "bootstrap/terraform.tfstate"  # Note different key path
    region         = "ap-south-1"
    encrypt        = true
    kms_key_id     = "76fa5abb-e9b5-4e54-a1bd-c7c7bde4bbf7"
    dynamodb_table = "terraform-lock-table"
  }
}