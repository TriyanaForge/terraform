# modules/networking/monitoring/variables.tf

variable "cloudwatch_log_groups" {
  description = "Map of CloudWatch Log Group configurations"
  type = map(object({
    name               = string
    retention_in_days  = number
    kms_key_id        = optional(string)
    tags              = map(string)
  }))
}

variable "metric_alarms" {
  description = "Map of CloudWatch Metric Alarm configurations"
  type = map(object({
    metric_name         = string
    namespace          = string
    comparison_operator = string
    evaluation_periods = number
    period            = number
    statistic         = string
    threshold         = number
    alarm_description = string
    alarm_actions     = list(string)
    dimensions        = map(string)
    tags             = map(string)
  }))
}

variable "dashboards" {
  description = "Map of CloudWatch Dashboard configurations"
  type = map(object({
    name  = string
    widgets = list(object({
      type       = string
      x          = number
      y          = number
      width      = number
      height     = number
      properties = any
    }))
    tags = map(string)
  }))
}

variable "vpc_flow_logs" {
  description = "Map of VPC Flow Log configurations"
  type = map(object({
    vpc_id            = string
    traffic_type      = string
    log_format        = optional(string)
    tags             = map(string)
  }))
}

variable "compliance_config" {
  description = "Monitoring compliance configuration"
  type = object({
    min_retention_days     = number
    enable_encryption      = bool
    enable_audit_logs     = bool
    required_metrics      = list(string)
    alert_thresholds      = map(number)
    mandatory_tags        = map(string)
    log_format_fields     = list(string)
    dashboard_refresh_rate = number
  })
  default = {
    min_retention_days     = 365  # GDPR requirement
    enable_encryption      = true
    enable_audit_logs     = true
    required_metrics      = [
      "NetworkIn",
      "NetworkOut",
      "CPUUtilization",
      "MemoryUtilization"
    ]
    alert_thresholds = {
      cpu_utilization    = 80
      memory_utilization = 80
      error_rate         = 5
      latency           = 1000
    }
    mandatory_tags = {
      DataClassification = "Confidential"
      Compliance        = "SOC2-GDPR"
    }
    log_format_fields = [
      "version",
      "account-id",
      "interface-id",
      "srcaddr",
      "dstaddr",
      "srcport",
      "dstport",
      "protocol",
      "packets",
      "bytes",
      "start",
      "end",
      "action",
      "log-status"
    ]
    dashboard_refresh_rate = 60
  }
}

variable "sns_topics" {
  description = "Map of SNS Topic configurations for alerts"
  type = map(object({
    name         = string
    display_name = optional(string)
    tags         = map(string)
  }))
}

variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "region" {
  type = string
}