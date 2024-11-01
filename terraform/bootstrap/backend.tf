# terraform/bootstrap/backend.tf
terraform {
  backend "s3" {
    bucket         = "triyanaforge-backend"
    key            = "bootstrap/terraform.tfstate"  # Note different key path
    region         = "ap-south-1"
    encrypt        = true
    kms_key_id     = "mrk-e034430d0f6b4de1bcc1c0e2b9689bb7"
    dynamodb_table = "terraform-lock-table"
  }
}