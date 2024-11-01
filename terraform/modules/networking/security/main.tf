# modules/networking/security/main.tf

# Security Groups
resource "aws_security_group" "main" {
  for_each = var.security_groups

  name_prefix = "${var.project}-${var.environment}-${each.value.name}"
  vpc_id      = each.value.vpc_id
  description = each.value.description

  tags = merge(
    each.value.tags,
    var.compliance_config.mandatory_tags,
    {
      Name = "${var.project}-${var.environment}-sg-${each.key}"
    }
  )
}

# Security Group Rules - Ingress
resource "aws_security_group_rule" "ingress" {
  for_each = {
    for pair in flatten([
      for sg_key, sg in var.security_groups : [
        for idx, rule in sg.ingress_rules : {
          key                = "${sg_key}-ingress-${idx}"
          security_group_id  = aws_security_group.main[sg_key].id
          from_port         = rule.from_port
          to_port           = rule.to_port
          protocol          = rule.protocol
          cidr_blocks       = rule.cidr_blocks
          description       = rule.description
          self             = rule.self
        }
      ]
    ]) : pair.key => pair
  }

  type              = "ingress"
  security_group_id = each.value.security_group_id
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  protocol          = each.value.protocol
  cidr_blocks       = each.value.cidr_blocks
  description       = each.value.description
  self              = each.value.self
}

# Security Group Rules - Egress
resource "aws_security_group_rule" "egress" {
  for_each = {
    for pair in flatten([
      for sg_key, sg in var.security_groups : [
        for idx, rule in sg.egress_rules : {
          key                = "${sg_key}-egress-${idx}"
          security_group_id  = aws_security_group.main[sg_key].id
          from_port         = rule.from_port
          to_port           = rule.to_port
          protocol          = rule.protocol
          cidr_blocks       = rule.cidr_blocks
          description       = rule.description
          self             = rule.self
        }
      ]
    ]) : pair.key => pair
  }

  type              = "egress"
  security_group_id = each.value.security_group_id
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  protocol          = each.value.protocol
  cidr_blocks       = each.value.cidr_blocks
  description       = each.value.description
  self              = each.value.self
}

# Network ACLs
resource "aws_network_acl" "main" {
  for_each = var.network_acls

  vpc_id     = each.value.vpc_id
  subnet_ids = each.value.subnet_ids

  tags = merge(
    each.value.tags,
    var.compliance_config.mandatory_tags,
    {
      Name = "${var.project}-${var.environment}-nacl-${each.key}"
    }
  )
}

# NACL Rules - Ingress
resource "aws_network_acl_rule" "ingress" {
  for_each = {
    for pair in flatten([
      for nacl_key, nacl in var.network_acls : [
        for rule in nacl.ingress_rules : {
          key           = "${nacl_key}-${rule.rule_no}"
          network_acl_id = aws_network_acl.main[nacl_key].id
          rule_no       = rule.rule_no
          protocol      = rule.protocol
          action        = rule.action
          cidr_block    = rule.cidr_block
          from_port     = rule.from_port
          to_port       = rule.to_port
        }
      ]
    ]) : pair.key => pair
  }

  network_acl_id = each.value.network_acl_id
  rule_number    = each.value.rule_no
  protocol       = each.value.protocol
  rule_action    = each.value.action
  cidr_block     = each.value.cidr_block
  from_port      = each.value.from_port
  to_port        = each.value.to_port
  egress         = false
}

# NACL Rules - Egress
resource "aws_network_acl_rule" "egress" {
  for_each = {
    for pair in flatten([
      for nacl_key, nacl in var.network_acls : [
        for rule in nacl.egress_rules : {
          key           = "${nacl_key}-${rule.rule_no}"
          network_acl_id = aws_network_acl.main[nacl_key].id
          rule_no       = rule.rule_no
          protocol      = rule.protocol
          action        = rule.action
          cidr_block    = rule.cidr_block
          from_port     = rule.from_port
          to_port       = rule.to_port
        }
      ]
    ]) : pair.key => pair
  }

  network_acl_id = each.value.network_acl_id
  rule_number    = each.value.rule_no
  protocol       = each.value.protocol
  rule_action    = each.value.action
  cidr_block     = each.value.cidr_block
  from_port      = each.value.from_port
  to_port        = each.value.to_port
  egress         = true
}

# WAF Web ACL
resource "aws_wafv2_web_acl" "main" {
  count = var.compliance_config.enable_waf ? 1 : 0

  name        = "${var.project}-${var.environment}-waf"
  description = "WAF Web ACL for compliance"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name               = "${var.project}-${var.environment}-waf-metrics"
    sampled_requests_enabled  = true
  }

  dynamic "rule" {
    for_each = var.waf_rules
    content {
      name     = rule.value.name
      priority = rule.value.priority

      override_action {
        none {}
      }

      statement {
        dynamic "rate_based_statement" {
          for_each = rule.value.rule_type == "rate_based" ? [1] : []
          content {
            limit = rule.value.rate_limit
            aggregate_key_type = "IP"
          }
        }

        dynamic "geo_match_statement" {
          for_each = rule.value.rule_type == "geo_match" ? [1] : []
          content {
            country_codes = rule.value.geo_restrictions
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name               = rule.value.name
        sampled_requests_enabled  = true
      }
    }
  }

  tags = merge(
    var.compliance_config.mandatory_tags,
    {
      Name = "${var.project}-${var.environment}-waf"
    }
  )
}

# GuardDuty
resource "aws_guardduty_detector" "main" {
  count = var.compliance_config.enable_guardduty ? 1 : 0

  enable = true

  datasources {
    s3_logs {
      enable = true
    }
    kubernetes {
      audit_logs {
        enable = true
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = true
        }
      }
    }
  }

  finding_publishing_frequency = "FIFTEEN_MINUTES"

  tags = merge(
    var.compliance_config.mandatory_tags,
    {
      Name = "${var.project}-${var.environment}-guardduty"
    }
  )
}

# Security Hub
resource "aws_securityhub_account" "main" {
  count = var.compliance_config.enable_security_hub ? 1 : 0
  enable_default_standards = true
}

# CloudWatch Log Group for Security Monitoring
resource "aws_cloudwatch_log_group" "security" {
  name              = "/aws/security/${var.project}-${var.environment}"
  retention_in_days = var.compliance_config.log_retention_days

  tags = merge(
    var.compliance_config.mandatory_tags,
    {
      Name = "${var.project}-${var.environment}-security-logs"
    }
  )
}