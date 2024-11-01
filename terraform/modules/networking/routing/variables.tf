# modules/networking/routing/variables.tf
variable "route_tables" {
  description = "Map of route table configurations"
  type = map(object({
    vpc_id        = string
    subnet_type   = string # "public", "private-app", "private-db"
    routes = list(object({
      cidr_block                = string
      gateway_id                = optional(string)
      nat_gateway_id            = optional(string)
      transit_gateway_id        = optional(string)
      vpc_peering_connection_id = optional(string)
      description              = string
    }))
    tags = map(string)
  }))
}

variable "nat_gateways" {
  description = "Map of NAT Gateway configurations"
  type = map(object({
    subnet_id     = string
    allocation_id = optional(string)
    private_ip    = optional(string)
    tags          = map(string)
  }))
}

variable "internet_gateways" {
  description = "Map of Internet Gateway configurations"
  type = map(object({
    vpc_id = string
    tags   = map(string)
  }))
}

variable "compliance_config" {
  description = "Compliance configuration for routing"
  type = object({
    enforce_encryption     = bool
    require_nat_gateway   = bool
    allowed_cidrs         = list(string)
    restrict_routing      = bool
    log_route_changes     = bool
    mandatory_tags        = map(string)
    enable_flow_logs      = bool
  })
  default = {
    enforce_encryption   = true
    require_nat_gateway = true
    allowed_cidrs       = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
    restrict_routing    = true
    log_route_changes   = true
    enable_flow_logs    = true
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