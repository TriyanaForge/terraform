# modules/networking/security/outputs.tf

output "security_group_ids" {
  description = "Map of security group IDs"
  value = {
    for k, v in aws_security_group.main : k => v.id
  }
}

output "security_group_arns" {
  description = "Map of security group ARNs"
  value = {
    for k, v in aws_security_group.main : k => v.arn
  }
}

output "security_group_names" {
  description = "Map of security group names"
  value = {
    for k, v in aws_security_group.main : k => v.name
  }
}

output "nacl_ids" {
  description = "Map of Network ACL IDs"
  value = {
    for k, v in aws_network_acl.main : k => v.id
  }
}

output "waf_web_acl_arn" {
  description = "ARN of WAF Web ACL"
  value = var.compliance_config.enable_waf ? aws_wafv2_web_acl.main[0].arn : null
}

output "waf_web_acl_id" {
  description = "ID of WAF Web ACL"
  value = var.compliance_config.enable_waf ? aws_wafv2_web_acl.main[0].id : null
}

output "guardduty_detector_id" {
  description = "ID of GuardDuty detector"
  value = var.compliance_config.enable_guardduty ? aws_guardduty_detector.main[0].id : null
}

output "security_hub_arn" {
  description = "ARN of Security Hub"
  value = var.compliance_config.enable_security_hub ? aws_securityhub_account.main[0].id : null
}

output "security_log_group_arn" {
  description = "ARN of Security CloudWatch Log Group"
  value = aws_cloudwatch_log_group.security.arn
}

output "compliance_status" {
  description = "Compliance status of security resources"
  value = {
    security_services = {
      waf_enabled          = var.compliance_config.enable_waf
      guardduty_enabled    = var.compliance_config.enable_guardduty
      security_hub_enabled = var.compliance_config.enable_security_hub
      security_logging_enabled = true
    }
    security_groups = {
      for k, v in aws_security_group.main : k => {
        id = v.id
        name = v.name
        compliant_ports = alltrue([
          for rule in var.security_groups[k].ingress_rules :
          contains(var.compliance_config.allowed_ports, rule.from_port) &&
          contains(var.compliance_config.allowed_ports, rule.to_port)
        ])
        compliant_protocols = alltrue([
          for rule in var.security_groups[k].ingress_rules :
          contains(var.compliance_config.allowed_protocols, rule.protocol)
        ])
        restricted_cidrs = alltrue([
          for rule in var.security_groups[k].ingress_rules :
          !contains(rule.cidr_blocks, "0.0.0.0/0") || 
          (contains([80, 443], rule.from_port) && contains([80, 443], rule.to_port))
        ])
      }
    }
    network_acls = {
      for k, v in aws_network_acl.main : k => {
        id = v.id
        subnet_count = length(var.network_acls[k].subnet_ids)
        rule_count = length(var.network_acls[k].ingress_rules) + length(var.network_acls[k].egress_rules)
      }
    }
    waf_configuration = var.compliance_config.enable_waf ? {
      enabled = true
      rules_count = length(var.waf_rules)
      geo_restrictions_enabled = length([
        for rule in var.waf_rules : rule
        if rule.rule_type == "geo_match"
      ]) > 0
    } : null
    logging = {
      retention_days = var.compliance_config.log_retention_days
      log_group_name = aws_cloudwatch_log_group.security.name
    }
  }
}

output "security_report" {
  description = "Detailed security compliance report"
  value = {
    timestamp = timestamp()
    environment = var.environment
    project = var.project
    region = var.region
    compliance_status = {
      soc2_compliant = alltrue([
        var.compliance_config.enable_waf,
        var.compliance_config.enable_guardduty,
        var.compliance_config.enable_security_hub,
        var.compliance_config.log_retention_days >= 365
      ])
      gdpr_compliant = alltrue([
        var.compliance_config.require_ssl,
        var.compliance_config.log_retention_days >= 365,
        length([
          for rule in var.waf_rules : rule
          if rule.rule_type == "geo_match"
        ]) > 0
      ])
    }
    security_findings = {
      high_risk_ports = [
        for k, v in var.security_groups : {
          security_group = k
          ports = [
            for rule in v.ingress_rules :
            rule.from_port
            if !contains(var.compliance_config.allowed_ports, rule.from_port)
          ]
        }
        if length([
          for rule in v.ingress_rules :
          rule.from_port
          if !contains(var.compliance_config.allowed_ports, rule.from_port)
        ]) > 0
      ]
      open_cidrs = [
        for k, v in var.security_groups : {
          security_group = k
          rules = [
            for rule in v.ingress_rules :
            {
              ports = "${rule.from_port}-${rule.to_port}"
              cidr = rule.cidr_blocks
            }
            if contains(rule.cidr_blocks, "0.0.0.0/0")
          ]
        }
        if length([
          for rule in v.ingress_rules :
          rule
          if contains(rule.cidr_blocks, "0.0.0.0/0")
        ]) > 0
      ]
    }
  }
}