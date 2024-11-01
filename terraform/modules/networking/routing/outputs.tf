# modules/networking/routing/outputs.tf
output "route_table_ids" {
  description = "Map of route table IDs"
  value = {
    for k, v in aws_route_table.main : k => v.id
  }
}

output "nat_gateway_ids" {
  description = "Map of NAT Gateway IDs"
  value = {
    for k, v in aws_nat_gateway.main : k => v.id
  }
}

output "internet_gateway_ids" {
  description = "Map of Internet Gateway IDs"
  value = {
    for k, v in aws_internet_gateway.main : k => v.id
  }
}

output "elastic_ip_addresses" {
  description = "Map of Elastic IP addresses"
  value = {
    for k, v in aws_eip.nat : k => v.public_ip
  }
}

output "compliance_status" {
  description = "Compliance status of routing resources"
  value = {
    routing_compliance = {
      route_logging_enabled = var.compliance_config.log_route_changes
      encryption_enforced = var.compliance_config.enforce_encryption
      route_restrictions = {
        enabled = var.compliance_config.restrict_routing
        allowed_cidrs = var.compliance_config.allowed_cidrs
      }
    }
    nat_gateways = {
      for k, v in aws_nat_gateway.main : k => {
        id = v.id
        monitoring_enabled = true
        encryption_in_transit = true
      }
    }
    route_tables = {
      for k, v in aws_route_table.main : k => {
        id = v.id
        subnet_type = var.route_tables[k].subnet_type
        compliant_routes = alltrue([
          for route in var.route_tables[k].routes :
          contains(var.compliance_config.allowed_cidrs, route.cidr_block)
        ])
      }
    }
  }
}