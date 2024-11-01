# modules/networking/routing/main.tf
# Internet Gateway
resource "aws_internet_gateway" "main" {
  for_each = var.internet_gateways
  
  vpc_id = each.value.vpc_id
  
  tags = merge(
    each.value.tags,
    var.compliance_config.mandatory_tags,
    {
      Name = "${var.project}-${var.environment}-igw-${each.key}"
    }
  )
}

# Elastic IPs for NAT Gateways
resource "aws_eip" "nat" {
  for_each = {
    for k, v in var.nat_gateways : k => v
    if v.allocation_id == null
  }
  
  domain = "vpc"
  
  tags = merge(
    each.value.tags,
    {
      Name = "${var.project}-${var.environment}-eip-${each.key}"
      Compliance = "SOC2-GDPR"
    }
  )
}

# NAT Gateways
resource "aws_nat_gateway" "main" {
  for_each = var.nat_gateways
  
  subnet_id     = each.value.subnet_id
  allocation_id = each.value.allocation_id != null ? each.value.allocation_id : aws_eip.nat[each.key].id
  private_ip    = each.value.private_ip
  
  tags = merge(
    each.value.tags,
    var.compliance_config.mandatory_tags,
    {
      Name = "${var.project}-${var.environment}-nat-${each.key}"
    }
  )
}

# Route Tables
resource "aws_route_table" "main" {
  for_each = var.route_tables
  
  vpc_id = each.value.vpc_id

  tags = merge(
    each.value.tags,
    var.compliance_config.mandatory_tags,
    {
      Name = "${var.project}-${var.environment}-rt-${each.key}"
      SubnetType = each.value.subnet_type
    }
  )
}

# Routes
resource "aws_route" "routes" {
  for_each = {
    for pair in flatten([
      for rt_key, rt in var.route_tables : [
        for route in rt.routes : {
          key           = "${rt_key}-${route.cidr_block}"
          rt_key        = rt_key
          cidr_block    = route.cidr_block
          gateway_id    = route.gateway_id
          nat_gateway_id = route.nat_gateway_id
          transit_gateway_id = route.transit_gateway_id
          vpc_peering_connection_id = route.vpc_peering_connection_id
        }
      ]
    ]) : pair.key => pair
  }

  route_table_id         = aws_route_table.main[each.value.rt_key].id
  destination_cidr_block = each.value.cidr_block
  gateway_id             = each.value.gateway_id
  nat_gateway_id         = each.value.nat_gateway_id
  transit_gateway_id     = each.value.transit_gateway_id
  vpc_peering_connection_id = each.value.vpc_peering_connection_id
}

# Route Table Association is handled in the subnet module

# CloudWatch Log Group for Route Changes
resource "aws_cloudwatch_log_group" "route_changes" {
  count = var.compliance_config.log_route_changes ? 1 : 0

  name              = "/aws/route-tables/${var.project}-${var.environment}"
  retention_in_days = 365 # GDPR requirement
  
  tags = {
    Name       = "${var.project}-${var.environment}-route-changes-log"
    Compliance = "SOC2-GDPR"
  }
}

# CloudTrail for Route Table Changes
resource "aws_cloudtrail" "route_changes" {
  count = var.compliance_config.log_route_changes ? 1 : 0

  name                          = "${var.project}-${var.environment}-route-changes"
  s3_bucket_name               = aws_s3_bucket.route_logs[0].id
  include_global_service_events = false
  is_multi_region_trail        = false
  
  event_selector {
    read_write_type           = "WriteOnly"
    include_management_events = true
  }
  
  tags = merge(
    var.compliance_config.mandatory_tags,
    {
      Name = "${var.project}-${var.environment}-route-changes-trail"
    }
  )
}

# S3 Bucket for Route Logs
resource "aws_s3_bucket" "route_logs" {
  count = var.compliance_config.log_route_changes ? 1 : 0

  bucket = "${var.project}-${var.environment}-route-logs"
  
  tags = merge(
    var.compliance_config.mandatory_tags,
    {
      Name = "${var.project}-${var.environment}-route-logs"
    }
  )
}

resource "aws_s3_bucket_server_side_encryption_configuration" "route_logs" {
  count = var.compliance_config.log_route_changes ? 1 : 0

  bucket = aws_s3_bucket.route_logs[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Monitoring Alarms
resource "aws_cloudwatch_metric_alarm" "nat_gateway_errors" {
  for_each = var.nat_gateways

  alarm_name          = "${var.project}-${var.environment}-nat-errors-${each.key}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ErrorPortAllocation"
  namespace           = "AWS/NATGateway"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "NAT Gateway port allocation errors"
  
  dimensions = {
    NatGatewayId = aws_nat_gateway.main[each.key].id
  }

  tags = {
    Name       = "${var.project}-${var.environment}-nat-alarm-${each.key}"
    Compliance = "SOC2-GDPR"
  }
}