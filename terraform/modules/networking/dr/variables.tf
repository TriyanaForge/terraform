# modules/networking/dr/variables.tf

variable "route53_health_checks" {
  description = "Map of Route53 health check configurations"
  type = map(object({
    fqdn              = string
    port              = number
    type              = string # "HTTP", "HTTPS", "TCP"
    resource_path     = optional(string)
    failure_threshold = number
    request_interval  = number
    regions          = optional(list(string))
    search_string    = optional(string)
    tags             = map(string)
  }))
}

variable "failover_records" {
  description = "Map of Route53 failover record configurations"
  type = map(object({
    zone_id         = string
    name            = string
    type            = string
    set_identifier  = string
    health_check_id = string
    failover        = string # PRIMARY or SECONDARY
    records         = optional(list(string))
    alias = optional(object({
      name                   = string
      zone_id               = string
      evaluate_target_health = bool
    }))
    tags = map(string)
  }))
}

variable "backup_plans" {
  description = "Map of AWS Backup plan configurations"
  type = map(object({
    schedule        = string
    retention_days = number
    vault_name     = string
    resources      = list(string)
    tags          = map(string)
  }))
}

variable "replication_config" {
  description = "Cross-region replication configuration"
  type = map(object({
    source_region      = string
    destination_region = string
    resource_type     = string # "S3", "EBS", "RDS"
    resource_id       = string
    kms_key_id       = optional(string)
    tags             = map(string)
  }))
}

variable "compliance_config" {
  description = "DR compliance configuration"
  type = object({
    rpo_requirements     = number  # Recovery Point Objective in minutes
    rto_requirements     = number  # Recovery Time Objective in minutes
    backup_encryption    = bool
    multi_region        = bool
    health_check_regions = list(string)
    mandatory_tags      = map(string)
    enable_monitoring   = bool
    retention_period    = number   # in days
  })
  default = {
    rpo_requirements     = 60     # 1 hour RPO
    rto_requirements     = 240    # 4 hours RTO
    backup_encryption    = true
    multi_region        = true
    health_check_regions = ["us-east-1", "eu-west-1", "ap-south-1"]
    mandatory_tags = {
      DataClassification = "Confidential"
      Compliance        = "SOC2-GDPR"
    }
    enable_monitoring   = true
    retention_period    = 365     # 1 year retention
  }
}

variable "transit_gateway_config" {
  description = "Transit Gateway configuration for DR"
  type = map(object({
    amazon_side_asn    = number
    auto_accept_shared_attachments = optional(bool)
    default_route_table_association = optional(string)
    default_route_table_propagation = optional(string)
    description        = string
    dns_support        = optional(string)
    vpn_ecmp_support   = optional(string)
    tags              = map(string)
  }))
}

variable "dns_failover_config" {
  description = "DNS failover configuration"
  type = map(object({
    primary_region    = string
    secondary_region  = string
    domain_name      = string
    record_type      = string
    evaluate_health  = bool
    tags            = map(string)
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