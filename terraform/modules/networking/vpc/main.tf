# modules/networking/vpc/main.tf
resource "aws_vpc" "main" {
  for_each = var.vpcs

  cidr_block           = each.value.cidr_block
  instance_tenancy     = each.value.instance_tenancy
  enable_dns_hostnames = each.value.enable_dns_hostnames
  enable_dns_support   = each.value.enable_dns_support

  # SOC2 Requirements
  enable_network_address_usage_metrics = true

  tags = merge(
    each.value.tags,
    {
      Name               = "${var.project}-${var.environment}-vpc-${each.key}"
      Compliance         = "SOC2-GDPR"
      DataClassification = "Confidential"
      DataResidency     = var.region
      CreatedBy         = "Terraform"
      ManagedBy         = "Platform-Team"
    }
  )
}

# KMS Key for Flow Logs Encryption
resource "aws_kms_key" "flow_logs" {
  for_each = var.vpcs

  description             = "KMS key for VPC Flow Logs encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name        = "${var.project}-${var.environment}-flow-logs-key-${each.key}"
    Compliance  = "SOC2-GDPR"
    Environment = var.environment
  }

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })
}

# CloudWatch Log Group for Flow Logs
resource "aws_cloudwatch_log_group" "flow_logs" {
  for_each = var.flow_logs_config

  name              = "/aws/vpc/${var.project}-${var.environment}-flow-logs-${each.key}"
  retention_in_days = each.value.retention_days
  kms_key_id        = aws_kms_key.flow_logs[each.key].arn

  tags = merge(
    each.value.tags,
    {
      Name        = "${var.project}-${var.environment}-flow-logs-${each.key}"
      Compliance  = "SOC2-GDPR"
      DataRetention = "${each.value.retention_days}-days"
    }
  )
}

# VPC Flow Logs
resource "aws_flow_log" "main" {
  for_each = var.flow_logs_config

  log_destination_type = each.value.log_destination_type
  log_destination     = aws_cloudwatch_log_group.flow_logs[each.key].arn
  traffic_type        = each.value.traffic_type
  vpc_id              = aws_vpc.main[each.key].id
  
  max_aggregation_interval = each.value.aggregation_interval

  tags = merge(
    each.value.tags,
    {
      Name       = "${var.project}-${var.environment}-flow-log-${each.key}"
      Compliance = "SOC2-GDPR"
      Purpose    = "Audit-Logs"
    }
  )
}

# IAM Role for Flow Logs
resource "aws_iam_role" "flow_logs" {
  for_each = var.vpcs

  name = "${var.project}-${var.environment}-flow-logs-role-${each.key}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name       = "${var.project}-${var.environment}-flow-logs-role-${each.key}"
    Compliance = "SOC2-GDPR"
  }
}

# IAM Policy for Flow Logs
resource "aws_iam_role_policy" "flow_logs" {
  for_each = var.vpcs

  name = "${var.project}-${var.environment}-flow-logs-policy-${each.key}"
  role = aws_iam_role.flow_logs[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          aws_cloudwatch_log_group.flow_logs[each.key].arn,
          "${aws_cloudwatch_log_group.flow_logs[each.key].arn}:*"
        ]
      }
    ]
  })
}