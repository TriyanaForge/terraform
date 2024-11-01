# modules/networking/dr/main.tf

# KMS Key for DR Encryption
resource "aws_kms_key" "dr" {
  count = var.compliance_config.backup_encryption ? 1 : 0

  description             = "KMS key for DR encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  multi_region           = var.compliance_config.multi_region

  tags = merge(
    var.compliance_config.mandatory_tags,
    {
      Name = "${var.project}-${var.environment}-dr-kms"
    }
  )
}

# Route53 Health Checks
resource "aws_route53_health_check" "main" {
  for_each = var.route53_health_checks

  fqdn              = each.value.fqdn
  port              = each.value.port
  type              = each.value.type
  resource_path     = each.value.resource_path
  failure_threshold = each.value.failure_threshold
  request_interval  = each.value.request_interval
  
  regions = coalesce(
    each.value.regions,
    var.compliance_config.health_check_regions
  )

  tags = merge(
    each.value.tags,
    var.compliance_config.mandatory_tags,
    {
      Name = "${var.project}-${var.environment}-health-check-${each.key}"
    }
  )
}

# Route53 Failover Records
resource "aws_route53_record" "failover" {
  for_each = var.failover_records

  zone_id         = each.value.zone_id
  name            = each.value.name
  type            = each.value.type
  set_identifier  = each.value.set_identifier

  failover_routing_policy {
    type = each.value.failover
  }

  health_check_id = each.value.health_check_id

  dynamic "alias" {
    for_each = each.value.alias != null ? [each.value.alias] : []
    content {
      name                   = alias.value.name
      zone_id               = alias.value.zone_id
      evaluate_target_health = alias.value.evaluate_target_health
    }
  }

  records = each.value.records
  ttl     = each.value.alias == null ? 60 : null

  lifecycle {
    create_before_destroy = true
  }
}

# AWS Backup Vault
resource "aws_backup_vault" "main" {
  for_each = var.backup_plans

  name        = "${var.project}-${var.environment}-${each.value.vault_name}"
  kms_key_arn = var.compliance_config.backup_encryption ? aws_kms_key.dr[0].arn : null

  tags = merge(
    each.value.tags,
    var.compliance_config.mandatory_tags,
    {
      Name = "${var.project}-${var.environment}-backup-vault-${each.key}"
    }
  )
}

# AWS Backup Plans
resource "aws_backup_plan" "main" {
  for_each = var.backup_plans

  name = "${var.project}-${var.environment}-backup-plan-${each.key}"

  rule {
    rule_name         = "backup-rule-${each.key}"
    target_vault_name = aws_backup_vault.main[each.key].name
    schedule          = each.value.schedule

    lifecycle {
      delete_after = var.compliance_config.retention_period
    }

    copy_action {
      destination_vault_arn = var.compliance_config.multi_region ? aws_backup_vault.replica[each.key].arn : null
    }
  }

  tags = merge(
    each.value.tags,
    var.compliance_config.mandatory_tags,
    {
      Name = "${var.project}-${var.environment}-backup-plan-${each.key}"
    }
  )
}

# Replica Backup Vault in Secondary Region
resource "aws_backup_vault" "replica" {
  provider = aws.secondary
  for_each = var.compliance_config.multi_region ? var.backup_plans : {}

  name        = "${var.project}-${var.environment}-${each.value.vault_name}-replica"
  kms_key_arn = var.compliance_config.backup_encryption ? aws_kms_key.dr[0].arn : null

  tags = merge(
    each.value.tags,
    var.compliance_config.mandatory_tags,
    {
      Name = "${var.project}-${var.environment}-backup-vault-replica-${each.key}"
    }
  )
}

# Transit Gateway for DR
resource "aws_ec2_transit_gateway" "main" {
  for_each = var.transit_gateway_config

  description                     = each.value.description
  amazon_side_asn                = each.value.amazon_side_asn
  auto_accept_shared_attachments = each.value.auto_accept_shared_attachments
  default_route_table_association = each.value.default_route_table_association
  default_route_table_propagation = each.value.default_route_table_propagation
  dns_support                    = each.value.dns_support
  vpn_ecmp_support              = each.value.vpn_ecmp_support

  tags = merge(
    each.value.tags,
    var.compliance_config.mandatory_tags,
    {
      Name = "${var.project}-${var.environment}-tgw-${each.key}"
    }
  )
}

# CloudWatch Alarms for Health Checks
resource "aws_cloudwatch_metric_alarm" "health_check" {
  for_each = var.compliance_config.enable_monitoring ? var.route53_health_checks : {}

  alarm_name          = "${var.project}-${var.environment}-health-${each.key}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = "60"
  statistic           = "Minimum"
  threshold           = "1"
  alarm_description   = "Health check status for ${each.value.fqdn}"

  dimensions = {
    HealthCheckId = aws_route53_health_check.main[each.key].id
  }

  alarm_actions = [aws_sns_topic.dr_alerts[0].arn]
  ok_actions    = [aws_sns_topic.dr_alerts[0].arn]

  tags = merge(
    var.compliance_config.mandatory_tags,
    {
      Name = "${var.project}-${var.environment}-health-alarm-${each.key}"
    }
  )
}

# SNS Topic for DR Alerts
resource "aws_sns_topic" "dr_alerts" {
  count = var.compliance_config.enable_monitoring ? 1 : 0

  name = "${var.project}-${var.environment}-dr-alerts"

  kms_master_key_id = var.compliance_config.backup_encryption ? aws_kms_key.dr[0].id : null

  tags = merge(
    var.compliance_config.mandatory_tags,
    {
      Name = "${var.project}-${var.environment}-dr-alerts"
    }
  )
}

# CloudWatch Dashboard for DR Monitoring
resource "aws_cloudwatch_dashboard" "dr" {
  count = var.compliance_config.enable_monitoring ? 1 : 0

  dashboard_name = "${var.project}-${var.environment}-dr-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        x    = 0
        y    = 0
        width = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/Route53", "HealthCheckStatus", "HealthCheckId", "*"]
          ]
          period = 60
          region = var.region
          title  = "Health Check Status"
        }
      },
      {
        type = "metric"
        x    = 12
        y    = 0
        width = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/Route53", "HealthCheckPercentageHealthy", "HealthCheckId", "*"]
          ]
          period = 60
          region = var.region
          title  = "Health Check Percentage"
        }
      }
    ]
  })
}