# modules/networking/subnets/main.tf
# Subnets
resource "aws_subnet" "main" {
  for_each = var.subnets

  vpc_id            = each.value.vpc_id
  cidr_block        = each.value.cidr_block
  availability_zone = each.value.availability_zone

  # SOC2 and GDPR compliance - Restrict automatic public IP assignment
  map_public_ip_on_launch = each.value.subnet_type == "public" && !var.compliance_config.restrict_public_ip

  # Validate region compliance
  lifecycle {
    precondition {
      condition     = contains(var.compliance_config.allowed_regions, var.region)
      error_message = "The specified region is not in the allowed regions list for compliance."
    }
  }

  tags = merge(
    each.value.tags,
    var.compliance_config.mandatory_tags,
    {
      Name               = "${var.project}-${var.environment}-${each.value.subnet_type}-${each.key}"
      SubnetType         = each.value.subnet_type
      DataResidency     = var.region
      AvailabilityZone  = each.value.availability_zone
      CreatedBy         = "Terraform"
      ManagedBy         = "Platform-Team"
    }
  )
}

# Network ACLs for subnet isolation
resource "aws_network_acl" "main" {
  for_each = var.compliance_config.enforce_subnet_isolation ? var.subnets : {}

  vpc_id     = each.value.vpc_id
  subnet_ids = [aws_subnet.main[each.key].id]

  tags = merge(
    each.value.tags,
    {
      Name        = "${var.project}-${var.environment}-nacl-${each.key}"
      Compliance  = "SOC2-GDPR"
      SubnetType  = each.value.subnet_type
    }
  )
}

# NACL Rules based on subnet type
resource "aws_network_acl_rule" "ingress" {
  for_each = var.compliance_config.enforce_subnet_isolation ? var.subnets : {}

  network_acl_id = aws_network_acl.main[each.key].id
  rule_number    = 100
  protocol       = -1
  rule_action    = "allow"
  egress         = false
  cidr_block     = each.value.subnet_type == "private-db" ? each.value.cidr_block : "0.0.0.0/0"
  
  lifecycle {
    precondition {
      condition     = each.value.subnet_type == "private-db" ? length(regexall("^\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}/\\d{1,2}$", each.value.cidr_block)) > 0 : true
      error_message = "Database subnet CIDR blocks must be valid and restricted."
    }
  }
}

resource "aws_network_acl_rule" "egress" {
  for_each = var.compliance_config.enforce_subnet_isolation ? var.subnets : {}

  network_acl_id = aws_network_acl.main[each.key].id
  rule_number    = 100
  protocol       = -1
  rule_action    = "allow"
  egress         = true
  cidr_block     = "0.0.0.0/0"
}

# Route Table Associations
resource "aws_route_table_association" "main" {
  for_each = var.subnets

  subnet_id      = aws_subnet.main[each.key].id
  route_table_id = data.aws_route_table.selected[each.value.subnet_type].id
}

# CloudWatch Metrics for Subnet Monitoring
resource "aws_cloudwatch_metric_alarm" "subnet_ip_usage" {
  for_each = var.subnets

  alarm_name          = "${var.project}-${var.environment}-ip-usage-${each.key}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "AvailableIPAddresses"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors subnet IP address usage"

  dimensions = {
    SubnetId = aws_subnet.main[each.key].id
  }

  alarm_actions = [data.aws_sns_topic.alerts.arn]
  ok_actions    = [data.aws_sns_topic.alerts.arn]

  tags = {
    Name       = "${var.project}-${var.environment}-ip-usage-alarm-${each.key}"
    Compliance = "SOC2-GDPR"
  }
}