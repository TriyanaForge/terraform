# modules/networking/monitoring/main.tf

# KMS Key for CloudWatch Logs Encryption
resource "aws_kms_key" "cloudwatch" {
  count = var.compliance_config.enable_encryption ? 1 : 0

  description             = "KMS key for CloudWatch Logs encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Action   = "kms:*"
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:CallerAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid    = "Allow CloudWatch Logs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(
    var.compliance_config.mandatory_tags,
    {
      Name = "${var.project}-${var.environment}-cloudwatch-kms"
    }
  )
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "main" {
  for_each = var.cloudwatch_log_groups

  name              = each.value.name
  retention_in_days = max(each.value.retention_in_days, var.compliance_config.min_retention_days)
  kms_key_id        = var.compliance_config.enable_encryption ? aws_kms_key.cloudwatch[0].arn : each.value.kms_key_id

  tags = merge(
    each.value.tags,
    var.compliance_config.mandatory_tags,
    {
      Name = "${var.project}-${var.environment}-log-group-${each.key}"
    }
  )
}

# SNS Topics for Alerts
resource "aws_sns_topic" "alerts" {
  for_each = var.sns_topics

  name         = "${var.project}-${var.environment}-${each.value.name}"
  display_name = each.value.display_name

  kms_master_key_id = var.compliance_config.enable_encryption ? aws_kms_key.cloudwatch[0].id : null

  tags = merge(
    each.value.tags,
    var.compliance_config.mandatory_tags,
    {
      Name = "${var.project}-${var.environment}-sns-${each.key}"
    }
  )
}

# CloudWatch Metric Alarms
resource "aws_cloudwatch_metric_alarm" "main" {
  for_each = var.metric_alarms

  alarm_name          = "${var.project}-${var.environment}-${each.key}"
  comparison_operator = each.value.comparison_operator
  evaluation_periods  = each.value.evaluation_periods
  metric_name         = each.value.metric_name
  namespace           = each.value.namespace
  period              = each.value.period
  statistic           = each.value.statistic
  threshold           = each.value.threshold
  alarm_description   = each.value.alarm_description
  alarm_actions       = each.value.alarm_actions
  dimensions          = each.value.dimensions

  tags = merge(
    each.value.tags,
    var.compliance_config.mandatory_tags,
    {
      Name = "${var.project}-${var.environment}-alarm-${each.key}"
    }
  )
}

# VPC Flow Logs with Enhanced Monitoring
resource "aws_flow_log" "vpc" {
  for_each = var.vpc_flow_logs

  vpc_id          = each.value.vpc_id
  traffic_type    = each.value.traffic_type
  log_destination = aws_cloudwatch_log_group.main["vpc-flow-logs"].arn
  
  log_format = coalesce(each.value.log_format,
    <<EOF
${jsonencode({
  version              = "$${version}"
  account-id           = "$${account-id}"
  interface-id         = "$${interface-id}"
  srcaddr              = "$${srcaddr}"
  dstaddr              = "$${dstaddr}"
  srcport              = "$${srcport}"
  dstport              = "$${dstport}"
  protocol             = "$${protocol}"
  packets              = "$${packets}"
  bytes                = "$${bytes}"
  start                = "$${start}"
  end                  = "$${end}"
  action               = "$${action}"
  log-status           = "$${log-status}"
  vpc-id               = "$${vpc-id}"
  subnet-id            = "$${subnet-id}"
  instance-id          = "$${instance-id}"
  type                 = "$${type}"
  tcp-flags            = "$${tcp-flags}"
  region               = "$${region}"
})}
EOF
  )

  tags = merge(
    each.value.tags,
    var.compliance_config.mandatory_tags,
    {
      Name = "${var.project}-${var.environment}-flow-log-${each.key}"
    }
  )
}

# CloudWatch Dashboards
resource "aws_cloudwatch_dashboard" "main" {
  for_each = var.dashboards

  dashboard_name = "${var.project}-${var.environment}-${each.value.name}"

  dashboard_body = jsonencode({
    widgets = each.value.widgets
    periodOverride = "auto"
    start         = "-P1D"  # Last 24 hours
    end           = "P0D"   # Now
  })
}

# Compliance Metric Filters
resource "aws_cloudwatch_log_metric_filter" "security_events" {
  for_each = var.compliance_config.enable_audit_logs ? var.cloudwatch_log_groups : {}

  name           = "${var.project}-${var.environment}-security-events-${each.key}"
  pattern        = "?ERROR ?WARN ?Authentication ?Authorization ?Security"
  log_group_name = aws_cloudwatch_log_group.main[each.key].name

  metric_transformation {
    name      = "SecurityEvents"
    namespace = "${var.project}/${var.environment}/Security"
    value     = "1"
    dimensions = {
      LogGroup = each.key
    }
  }
}

# Compliance Alarms
resource "aws_cloudwatch_metric_alarm" "security_events" {
  for_each = var.compliance_config.enable_audit_logs ? var.cloudwatch_log_groups : {}

  alarm_name          = "${var.project}-${var.environment}-security-events-${each.key}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "SecurityEvents"
  namespace           = "${var.project}/${var.environment}/Security"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "Security events detected in log group ${each.key}"
  alarm_actions       = [for topic in aws_sns_topic.alerts : topic.arn]

  dimensions = {
    LogGroup = each.key
  }

  tags = merge(
    var.compliance_config.mandatory_tags,
    {
      Name = "${var.project}-${var.environment}-security-alarm-${each.key}"
    }
  )
}

# Log Insights Queries
resource "aws_cloudwatch_query_definition" "security_analysis" {
  for_each = var.compliance_config.enable_audit_logs ? var.cloudwatch_log_groups : {}

  name = "${var.project}-${var.environment}-security-analysis-${each.key}"

  log_group_names = [aws_cloudwatch_log_group.main[each.key].name]

  query_string = <<-EOF
  fields @timestamp, @message
  | filter @message like /(?i)(error|warn|authentication|authorization|security)/
  | sort @timestamp desc
  | limit 100
  EOF
}

# Service Quotas Monitoring
resource "aws_cloudwatch_metric_alarm" "service_quotas" {
  for_each = toset(var.compliance_config.required_metrics)

  alarm_name          = "${var.project}-${var.environment}-quota-${each.key}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = each.key
  namespace           = "AWS/ServiceQuotas"
  period              = "300"
  statistic           = "Maximum"
  threshold           = lookup(var.compliance_config.alert_thresholds, each.key, 80)
  alarm_description   = "Service quota utilization alert for ${each.key}"
  alarm_actions       = [for topic in aws_sns_topic.alerts : topic.arn]

  tags = merge(
    var.compliance_config.mandatory_tags,
    {
      Name = "${var.project}-${var.environment}-quota-alarm-${each.key}"
    }
  )
}