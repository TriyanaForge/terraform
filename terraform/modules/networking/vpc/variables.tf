# modules/networking/vpc/variables.tf
variable "vpcs" {
  description = "Map of VPC configurations"
  type = map(object({
    cidr_block           = string
    instance_tenancy     = string
    enable_dns_hostnames = bool
    enable_dns_support   = bool
    azs                  = list(string)
    tags                 = map(string)
  }))
}

variable "flow_logs_config" {
  description = "VPC Flow Logs configuration"
  type = map(object({
    traffic_type         = string
    log_destination_type = string
    retention_days      = number
    aggregation_interval = number
    tags                = map(string)
  }))
}

variable "vpc_compliance_config" {
  description = "Compliance configuration settings"
  type = object({
    data_retention_days = number
    log_encryption     = bool
    require_ssl        = bool
    allowed_regions    = list(string)
    allowed_countries  = list(string)
    audit_log_enabled  = bool
  })
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