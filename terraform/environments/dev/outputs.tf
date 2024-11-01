# environments/dev/outputs.tf

# VPC Outputs
output "vpc_ids" {
  description = "Map of VPC IDs"
  value       = module.vpc.vpc_ids
}

output "vpc_cidr_blocks" {
  description = "Map of VPC CIDR blocks"
  value       = module.vpc.vpc_cidr_blocks
}

# Subnet Outputs
output "subnet_ids" {
  description = "Map of subnet IDs"
  value       = module.subnets.subnet_ids
}

output "subnet_cidr_blocks" {
  description = "Map of subnet CIDR blocks"
  value       = module.subnets.subnet_cidr_blocks
}

# Security Group Outputs
output "security_group_ids" {
  description = "Map of security group IDs"
  value       = module.security.security_group_ids
}

# Route Table Outputs
output "route_table_ids" {
  description = "Map of route table IDs"
  value       = module.routing.route_table_ids
}

# Monitoring Outputs
output "log_group_arns" {
  description = "Map of CloudWatch Log Group ARNs"
  value       = module.monitoring.log_group_arns
}

output "metric_alarm_arns" {
  description = "Map of CloudWatch Metric Alarm ARNs"
  value       = module.monitoring.metric_alarm_arns
}

# DR Outputs
output "health_check_ids" {
  description = "Map of Route53 Health Check IDs"
  value       = module.dr.health_check_ids
}

output "backup_vault_arns" {
  description = "Map of Backup Vault ARNs"
  value       = module.dr.backup_vault_arns
}

# Compliance Status
output "compliance_status" {
  description = "Overall compliance status"
  value = {
    vpc_compliance        = module.vpc.compliance_status
    security_compliance   = module.security.compliance_status
    monitoring_compliance = module.monitoring.monitoring_status
    dr_compliance        = module.dr.dr_status
  }
}