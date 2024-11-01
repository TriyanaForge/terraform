# Locals for managing dependencies
locals {
  vpc_id = module.vpc.vpc_ids["main"]

  # Merge VPC ID into subnet configurations
  subnet_configs = {
    for k, v in var.subnets : k => merge(v, {
      vpc_id = local.vpc_id
    })
  }

  # Merge VPC ID into security group configurations
  security_group_configs = {
    for k, v in var.security_groups : k => merge(v, {
      vpc_id = local.vpc_id
    })
  }

  # Merge VPC ID into route table configurations
  route_table_configs = {
    for k, v in var.route_tables : k => merge(v, {
      vpc_id = local.vpc_id
    })
  }

  # Merge VPC ID into network ACL configurations
  network_acl_configs = {
    for k, v in var.network_acls : k => merge(v, {
      vpc_id = local.vpc_id
    })
  }

  # Merge VPC ID into NAT gateway configurations
  nat_gateway_configs = {
    for k, v in var.nat_gateways : k => merge(v, {
      subnet_id = module.subnets.subnet_ids[v.subnet_name]
    })
  }

  # Merge VPC ID into internet gateway configurations
  internet_gateway_configs = {
    for k, v in var.internet_gateways : k => merge(v, {
      vpc_id = local.vpc_id
    })
  }
}

# VPC Module
module "vpc" {
  source = "../../modules/networking/vpc"

  project           = var.project
  environment       = var.environment
  region            = var.region
  vpcs              = var.vpcs
  compliance_config = var.compliance_config
  flow_logs_config  = var.flow_logs_config
}

# Subnet Module
module "subnets" {
  source = "../../modules/networking/subnets"
  
  project     = var.project
  environment = var.environment
  region      = var.region
  subnets     = local.subnet_configs

  depends_on = [module.vpc]
}

# Routing Module
module "routing" {
  source = "../../modules/networking/routing"
  
  project            = var.project
  environment        = var.environment
  route_tables       = local.route_table_configs
  nat_gateways       = local.nat_gateway_configs
  internet_gateways  = local.internet_gateway_configs
  compliance_config  = var.compliance_config

  depends_on = [module.vpc, module.subnets]
}

# Security Module
module "security" {
  source = "../../modules/networking/security"
  
  project         = var.project
  environment     = var.environment
  region          = var.region
  security_groups = local.security_group_configs
  waf_rules       = var.waf_rules
  network_acls    = local.network_acl_configs
  compliance_config = var.compliance_config

  depends_on = [module.vpc]
}

# Monitoring Module
module "monitoring" {
  source = "../../modules/networking/monitoring"
  
  project               = var.project
  environment          = var.environment
  region               = var.region
  cloudwatch_log_groups = var.cloudwatch_log_groups
  metric_alarms        = var.metric_alarms
  compliance_config    = var.compliance_config
  vpc_flow_logs = var.vpc_flow_logs
  dashboards = var.dashboards
  sns_topics = var.sns_topics

  depends_on = [module.vpc, module.security]
}

# DR Module
module "dr" {
  source = "../../modules/networking/dr"
  
  project               = var.project
  environment           = var.environment
  region                = var.region
  route53_health_checks = var.route53_health_checks
  backup_plans          = var.backup_plans
  failover_records      = var.failover_records
  transit_gateway_config = var.transit_gateway_config
  replication_config    = var.replication_config
  dns_failover_config   = var.dns_failover_config
  compliance_config     = var.compliance_config

  depends_on = [module.vpc, module.monitoring]
}