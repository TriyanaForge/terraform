# Main State Bucket
resource "aws_s3_bucket" "terraform_state_primary" {
  bucket = "${var.resource_prefix}-${var.environment}-${var.primary_region}-tf-state-bucket"

  tags = {
    Name        = "Terraform Primary State Bucket"
    Environment = var.environment
    Project     = var.project

  }
}

# Versioning
resource "aws_s3_bucket_versioning" "terraform_state_primary" {
  bucket = aws_s3_bucket.terraform_state_primary.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Encryption Configuration
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state_primary" {
  bucket = aws_s3_bucket.terraform_state_primary.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.terraform_primary_bucket_key.id
    }
  }
}

# Public Access Block
resource "aws_s3_bucket_public_access_block" "terraform_state_primary" {
  bucket = aws_s3_bucket.terraform_state_primary.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Logging Bucket
resource "aws_s3_bucket" "terraform_logs" {
  bucket = "${var.project}-${var.environment}-${var.primary_region}-tf-log-bucket"

  tags = {
    Name        = "Terraform Primary State Log Bucket"
    Environment = var.environment
    Project     = var.project
  }
}

# Enable Logging
resource "aws_s3_bucket_logging" "terraform_state_primary" {
  bucket = aws_s3_bucket.terraform_state_primary.id

  target_bucket = aws_s3_bucket.terraform_logs.id
  target_prefix = "log/"
}

# Bucket Policy for SSL
resource "aws_s3_bucket_policy" "terraform_state_primary" {
  bucket = aws_s3_bucket.terraform_state_primary.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnforceTLS"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.terraform_state_primary.arn,
          "${aws_s3_bucket.terraform_state_primary.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# Lifecycle Rules
resource "aws_s3_bucket_lifecycle_configuration" "terraform_state_primary" {
  bucket = aws_s3_bucket.terraform_state_primary.id
  rule {
    id     = "state_cleanup"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# Replica Bucket
# Replica Bucket
resource "aws_s3_bucket" "terraform_state_replica" {
  provider = aws.replica
  bucket   = "${var.project}-${var.environment}-${var.replica_region}-tf-state-replica"

  # Force destroy for testing - remove in production
  force_destroy = true

  tags = {
    Name        = "Terraform State Replica Bucket"
    Environment = var.environment
    Project     = var.project
  }
}

# Enable versioning on replica bucket
resource "aws_s3_bucket_versioning" "terraform_state_replica" {
  provider = aws.replica
  bucket   = aws_s3_bucket.terraform_state_replica.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# IAM Role for replication
resource "aws_iam_role" "replication" {
  name = "${var.project}-${var.environment}-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for replication
resource "aws_iam_role_policy" "replication" {
  name = "${var.project}-${var.environment}-replication-policy"
  role = aws_iam_role.replication.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.terraform_state_primary.arn
        ]
      },
      {
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ]
        Effect = "Allow"
        Resource = [
          "${aws_s3_bucket.terraform_state_primary.arn}/*"
        ]
      },
      {
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]
        Effect = "Allow"
        Resource = [
          "${aws_s3_bucket.terraform_state_replica.arn}/*"
        ]
      }
    ]
  })
}

# Replication configuration
# Replication configuration
resource "aws_s3_bucket_replication_configuration" "terraform_state_replica" {
  depends_on = [
    aws_s3_bucket_versioning.terraform_state_primary,
    aws_s3_bucket_versioning.terraform_state_replica
  ]

  role   = aws_iam_role.replication.arn
  bucket = aws_s3_bucket.terraform_state_primary.id

  rule {
    id     = "terraform_state_replication"
    status = "Enabled"

    # Add delete marker replication
    delete_marker_replication {
      status = "Enabled"
    }

    filter {
      prefix = "dev/"
    }

    destination {
      bucket        = aws_s3_bucket.terraform_state_replica.arn
      storage_class = "STANDARD_IA"

      # Add metrics configurations
      metrics {
        status = "Enabled"
        event_threshold {
          minutes = 15
        }
      }

      # Add replication time control
      replication_time {
        status = "Enabled"
        time {
          minutes = 15
        }
      }
    }
  }
}