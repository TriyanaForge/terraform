# modules/networking/subnets/outputs.tf
output "subnet_ids" {
  description = "Map of subnet IDs"
  value = {
    for k, v in aws_subnet.main : k => v.id
  }
}

output "subnet_arns" {
  description = "Map of subnet ARNs"
  value = {
    for k, v in aws_subnet.main : k => v.arn
  }
}

output "subnet_cidr_blocks" {
  description = "Map of subnet CIDR blocks"
  value = {
    for k, v in aws_subnet.main : k => v.cidr_block
  }
}

output "nacl_ids" {
  description = "Map of Network ACL IDs"
  value = {
    for k, v in aws_network_acl.main : k => v.id
  }
}

output "compliance_status" {
  description = "Compliance status of subnet resources"
  value = {
    for k, v in aws_subnet.main : k => {
      subnet_id = v.id
      subnet_type = var.subnets[k].subnet_type
      compliance_checks = {
        public_ip_restricted = !v.map_public_ip_on_launch
        nacl_enabled = var.compliance_config.enforce_subnet_isolation
        compliant_region = contains(var.compliance_config.allowed_regions, var.region)
        mandatory_tags_applied = alltrue([
          for tag_key, tag_value in var.compliance_config.mandatory_tags : 
          contains(keys(v.tags), tag_key)
        ])
      }
      monitoring = {
        ip_usage_alarm_enabled = true
        alarm_threshold = "80%"
      }
      data_residency = var.region
    }
  }
}