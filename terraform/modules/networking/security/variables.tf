# modules/networking/security/variables.tf
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

variable "security_compliance_config" {
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

variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "region" {
  type = string
}