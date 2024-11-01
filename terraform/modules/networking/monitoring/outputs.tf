# modules/networking/monitoring/outputs.tf

output "log_group_arns" {
  description = "Map of CloudWatch Log Group ARNs"
  value = {
    for k, v in aws_cloudwatch_log_group.main : k => v.arn
  }
}

output "log_group_names" {
  description = "Map of CloudWatch Log Group names"
  value = {
    for k, v in aws_cloudwatch_log_group.main : k => v.name
  }
}

output "sns_topic_arns" {
  description = "Map of SNS Topic ARNs"
  value = {
    for k, v in aws_sns_topic.alerts : k => v.arn
  }
}

output "metric_alarm_arns" {
  description = "Map of CloudWatch Metric Alarm ARNs"
  value = {
    for k, v in aws_cloudwatch_metric_alarm.main : k => v.arn
  }
}

output "dashboard_arns" {
  description = "Map of CloudWatch Dashboard ARNs"
  value = {
    for k, v in aws_cloudwatch_dashboard.main : k => v.dashboard_arn
  }
}

output "flow_log_ids" {
  description = "Map of VPC Flow Log IDs"
  value = {
    for k, v in aws_flow_log.vpc : k => v.id
  }
}

output "kms_key_arn" {
  description = "ARN of KMS key used for encryption"
  value = var.compliance_config.enable_encryption ? aws_kms_key.cloudwatch[0].arn : null
}

output "monitoring_status" {
  description = "Comprehensive monitoring status and compliance information"
  value = {
    log_groups = {
      for k, v in aws_cloudwatch_log_group.main : k => {
        name = v.name
        retention_days = v.retention_in_days
        encryption_enabled = var.compliance_config.enable_encryption
        compliant_retention = v.retention_in_days >= var.compliance_config.min_retention_days
      }
    }
    flow_logs = {
      for k, v in aws_flow_log.vpc : k => {
        id = v.id
        vpc_id = v.vpc_id
        traffic_type = v.traffic_type
        log_format_fields = length(regexall("\\$\\{[^}]+\\}", v.log_format))
      }
    }
    alarms = {
      metric_alarms = {
        for k, v in aws_cloudwatch_metric_alarm.main : k => {
          name = v.alarm_name
          metric = v.metric_name
          threshold = v.threshold
        }
      }
      security_alarms = {
        for k, v in aws_cloudwatch_metric_alarm.security_events : k => {
          name = v.alarm_name
          log_group = k
        }
      }
      quota_alarms = {
        for k, v in aws_cloudwatch_metric_alarm.service_quotas : k => {
          name = v.alarm_name
          metric = k
          threshold = v.threshold
        }
      }
    }
    compliance = {
      encryption_enabled = var.compliance_config.enable_encryption
      audit_logs_enabled = var.compliance_config.enable_audit_logs
      min_retention_days = var.compliance_config.min_retention_days
      required_metrics_monitored = toset(var.compliance_config.required_metrics)
      soc2_compliant = alltrue([
        var.compliance_config.enable_encryption,
        var.compliance_config.enable_audit_logs,
        var.compliance_config.min_retention_days >= 365
      ])
      gdpr_compliant = alltrue([
        var.compliance_config.enable_encryption,
        var.compliance_config.min_retention_days >= 365,
        var.compliance_config.enable_audit_logs
      ])
    }
  }
}

output "monitoring_report" {
  description = "Detailed monitoring and compliance report"
  value = {
    timestamp = timestamp()
    environment = var.environment
    project = var.project
    region = var.region
    metrics_monitored = length(var.metric_alarms)
    security_events_monitored = var.compliance_config.enable_audit_logs
    encryption_status = var.compliance_config.enable_encryption
    retention_compliance = {
      for k, v in aws_cloudwatch_log_group.main : k => 
      v.retention_in_days >= var.compliance_config.min_retention_days
    }
    alarm_thresholds = var.compliance_config.alert_thresholds
    monitoring_coverage = {
      log_groups = length(var.cloudwatch_log_groups)
      metric_alarms = length(var.metric_alarms)
      flow_logs = length(var.vpc_flow_logs)
      security_queries = var.compliance_config.enable_audit_logs ? length(var.cloudwatch_log_groups) : 0
    }
  }
}

output "query_definitions" {
  description = "Map of Log Insights query definitions"
  value = {
    for k, v in aws_cloudwatch_query_definition.security_analysis : k => {
      name = v.name
      query = v.query_string
    }
  }
}