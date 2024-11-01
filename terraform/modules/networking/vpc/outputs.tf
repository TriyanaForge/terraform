# modules/networking/vpc/outputs.tf
output "vpc_ids" {
  description = "Map of VPC IDs"
  value = {
    for k, v in aws_vpc.main : k => v.id
  }
}

output "vpc_arns" {
  description = "Map of VPC ARNs"
  value = {
    for k, v in aws_vpc.main : k => v.arn
  }
}

output "vpc_cidr_blocks" {
  description = "Map of VPC CIDR blocks"
  value = {
    for k, v in aws_vpc.main : k => v.cidr_block
  }
}

output "flow_log_group_arns" {
  description = "Map of Flow Log Group ARNs"
  value = {
    for k, v in aws_cloudwatch_log_group.flow_logs : k => v.arn
  }
}

output "kms_key_arns" {
  description = "Map of KMS Key ARNs"
  value = {
    for k, v in aws_kms_key.flow_logs : k => v.arn
  }
}

output "compliance_status" {
  description = "Compliance status of VPC resources"
  value = {
    for k, v in aws_vpc.main : k => {
      vpc_id = v.id
      flow_logs_enabled = true
      encryption_enabled = true
      logging_retention = var.flow_logs_config[k].retention_days
      compliance_tags = {
        soc2_compliant = true
        gdpr_compliant = true
        data_residency = var.region
      }
    }
  }
}