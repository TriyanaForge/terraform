# modules/networking/dr/outputs.tf

output "health_check_ids" {
  description = "Map of Route53 Health Check IDs"
  value = {
    for k, v in aws_route53_health_check.main : k => v.id
  }
}

output "failover_record_fqdns" {
  description = "Map of Route53 Failover Record FQDNs"
  value = {
    for k, v in aws_route53_record.failover : k => v.fqdn
  }
}

output "backup_vault_arns" {
  description = "Map of Backup Vault ARNs"
  value = {
    primary = {
      for k, v in aws_backup_vault.main : k => v.arn
    }
    replica = var.compliance_config.multi_region ? {
      for k, v in aws_backup_vault.replica : k => v.arn
    } : null
  }
}

output "backup_plan_arns" {
  description = "Map of Backup Plan ARNs"
  value = {
    for k, v in aws_backup_plan.main : k => v.arn
  }
}

output "transit_gateway_ids" {
  description = "Map of Transit Gateway IDs"
  value = {
    for k, v in aws_ec2_transit_gateway.main : k => v.id
  }
}

output "kms_key_arn" {
  description = "ARN of KMS key used for DR encryption"
  value = var.compliance_config.backup_encryption ? aws_kms_key.dr[0].arn : null
}

output "sns_topic_arn" {
  description = "ARN of SNS topic for DR alerts"
  value = var.compliance_config.enable_monitoring ? aws_sns_topic.dr_alerts[0].arn : null
}

output "dr_status" {
  description = "Comprehensive DR status and compliance information"
  value = {
    health_checks = {
      for k, v in aws_route53_health_check.main : k => {
        id = v.id
        fqdn = v.fqdn
        type = v.type
        regions = coalesce(
          var.route53_health_checks[k].regions,
          var.compliance_config.health_check_regions
        )
        monitoring_enabled = var.compliance_config.enable_monitoring
      }
    }
    failover_records = {
      for k, v in aws_route53_record.failover : k => {
        name = v.name
        type = v.type
        failover_type = var.failover_records[k].failover
        health_check_enabled = v.health_check_id != null
      }
    }
    backup_configuration = {
      for k, v in aws_backup_plan.main : k => {
        vault_name = aws_backup_vault.main[k].name
        schedule = var.backup_plans[k].schedule
        retention_days = var.compliance_config.retention_period
        encryption_enabled = var.compliance_config.backup_encryption
        multi_region_enabled = var.compliance_config.multi_region
      }
    }
    compliance = {
      rpo_status = {
        requirement = var.compliance_config.rpo_requirements
        achieved = min([
          for plan in var.backup_plans : 
          parse_duration(plan.schedule)
        ])
      }
      rto_status = {
        requirement = var.compliance_config.rto_requirements
        monitoring_enabled = var.compliance_config.enable_monitoring
      }
      encryption_status = {
        enabled = var.compliance_config.backup_encryption
        kms_key_rotation = var.compliance_config.backup_encryption
        multi_region = var.compliance_config.multi_region
      }
      monitoring_status = {
        health_checks_monitored = var.compliance_config.enable_monitoring
        alerts_configured = var.compliance_config.enable_monitoring
        dashboard_enabled = var.compliance_config.enable_monitoring
      }
    }
  }
}

output "dr_compliance_report" {
  description = "Detailed DR compliance report"
  value = {
    timestamp = timestamp()
    environment = var.environment
    project = var.project
    region = var.region
    soc2_compliant = alltrue([
      var.compliance_config.backup_encryption,
      var.compliance_config.enable_monitoring,
      var.compliance_config.retention_period >= 365
    ])
    gdpr_compliant = alltrue([
      var.compliance_config.backup_encryption,
      var.compliance_config.multi_region,
      var.compliance_config.retention_period >= 365
    ])
    metrics = {
      health_checks_count = length(var.route53_health_checks)
      failover_records_count = length(var.failover_records)
      backup_plans_count = length(var.backup_plans)
      monitored_regions = length(var.compliance_config.health_check_regions)
    }
    recovery_objectives = {
      rpo = {
        target = var.compliance_config.rpo_requirements
        unit = "minutes"
      }
      rto = {
        target = var.compliance_config.rto_requirements
        unit = "minutes"
      }
    }
    backup_strategy = {
      encryption_enabled = var.compliance_config.backup_encryption
      multi_region_enabled = var.compliance_config.multi_region
      retention_period = var.compliance_config.retention_period
    }
    monitoring_status = {
      enabled = var.compliance_config.enable_monitoring
      alerts_configured = var.compliance_config.enable_monitoring
      health_checks_monitored = length(var.route53_health_checks) > 0
    }
  }
}