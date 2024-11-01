# environments/dev/variables.tf

variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "region" {
  type = string
}

# VPC Variables
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

variable "compliance_config" {
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

# Subnet Variables
variable "subnets" {
  description = "Map of subnet configurations"
  type = map(object({
    vpc_id            = string
    cidr_block        = string
    availability_zone = string
    subnet_type       = string # "public", "private-app", "private-db"
    nat_gateway      = optional(bool, false)
    tags             = map(string)
  }))
}

variable "compliance_config" {
  description = "Compliance configuration for subnets"
  type = object({
    enforce_subnet_isolation = bool
    restrict_public_ip      = bool
    allowed_regions        = list(string)
    require_resource_tags  = bool
    mandatory_tags        = map(string)
  })
  default = {
    enforce_subnet_isolation = true
    restrict_public_ip      = true
    allowed_regions        = ["eu-west-1", "eu-central-1", "ap-south-1"]
    require_resource_tags  = true
    mandatory_tags = {
      DataClassification = "Confidential"
      Compliance        = "SOC2-GDPR"
    }
  }
}

# Security Group Variables
variable "security_groups" {
  description = "Map of security group configurations"
  type = map(object({
    vpc_id      = string
    name        = string
    description = string
    ingress_rules = list(object({
      from_port   = number
      to_port     = number
      protocol    = string
      cidr_blocks = list(string)
      description = string
      self        = optional(bool, false)
    }))
    egress_rules = list(object({
      from_port   = number
      to_port     = number
      protocol    = string
      cidr_blocks = list(string)
      description = string
      self        = optional(bool, false)
    }))
    tags = map(string)
  }))
}

variable "network_acls" {
  description = "Map of Network ACL configurations"
  type = map(object({
    vpc_id     = string
    subnet_ids = list(string)
    ingress_rules = list(object({
      rule_no    = number
      protocol   = string
      action     = string
      cidr_block = string
      from_port  = number
      to_port    = number
    }))
    egress_rules = list(object({
      rule_no    = number
      protocol   = string
      action     = string
      cidr_block = string
      from_port  = number
      to_port    = number
    }))
    tags = map(string)
  }))
}

variable "waf_rules" {
  description = "Map of WAF rule configurations"
  type = map(object({
    name             = string
    description      = string
    priority         = number
    rule_type        = string # "rate_based", "geo_match"
    rate_limit       = optional(number)
    geo_restrictions = optional(list(string))
    tags             = map(string)
  }))
}

variable "compliance_config" {
  description = "Security compliance configuration"
  type = object({
    enable_waf           = bool
    enable_security_hub  = bool
    enable_guardduty     = bool
    enable_shield        = bool
    allowed_ports        = list(number)
    allowed_protocols    = list(string)
    restricted_cidrs     = list(string)
    require_ssl          = bool
    log_retention_days   = number
    mandatory_tags       = map(string)
  })
  default = {
    enable_waf           = true
    enable_security_hub  = true
    enable_guardduty     = true
    enable_shield        = true
    allowed_ports        = [80, 443, 22]
    allowed_protocols    = ["tcp", "udp"]
    restricted_cidrs     = ["0.0.0.0/0"]
    require_ssl          = true
    log_retention_days   = 365
    mandatory_tags = {
      DataClassification = "Confidential"
      Compliance        = "SOC2-GDPR"
    }
  }
}

# Route Tables Variables
variable "route_tables" {
  description = "Map of route table configurations"
  type = map(object({
    vpc_id        = string
    subnet_type   = string # "public", "private-app", "private-db"
    routes = list(object({
      cidr_block                = string
      gateway_id                = optional(string)
      nat_gateway_id            = optional(string)
      transit_gateway_id        = optional(string)
      vpc_peering_connection_id = optional(string)
      description              = string
    }))
    tags = map(string)
  }))
}

variable "nat_gateways" {
  description = "Map of NAT Gateway configurations"
  type = map(object({
    subnet_id     = string
    allocation_id = optional(string)
    private_ip    = optional(string)
    tags          = map(string)
  }))
}

variable "internet_gateways" {
  description = "Map of Internet Gateway configurations"
  type = map(object({
    vpc_id = string
    tags   = map(string)
  }))
}

variable "compliance_config" {
  description = "Compliance configuration for routing"
  type = object({
    enforce_encryption     = bool
    require_nat_gateway   = bool
    allowed_cidrs         = list(string)
    restrict_routing      = bool
    log_route_changes     = bool
    mandatory_tags        = map(string)
    enable_flow_logs      = bool
  })
  default = {
    enforce_encryption   = true
    require_nat_gateway = true
    allowed_cidrs       = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
    restrict_routing    = true
    log_route_changes   = true
    enable_flow_logs    = true
    mandatory_tags = {
      DataClassification = "Confidential"
      Compliance        = "SOC2-GDPR"
    }
  }
}


# Monitoring Variables
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

# DR Variables
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

