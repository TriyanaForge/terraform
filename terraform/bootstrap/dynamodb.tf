resource "aws_dynamodb_table" "terraform_primary_lock" {
  name         = "${var.project}-${var.environment}-tf-state-lock-01"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Environment = var.environment
    Project     = var.project
    Purpose     = "terraform-state-lock"
  }
}