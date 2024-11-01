# modules/networking/subnets/variables.tf
variable "subnets" {
  description = "Map of subnet configurations"
  type = map(object({
    vpc_id            = string
    cidr_block        = string
    availability_zone = string
    subnet_type       = string # "public", "private-app", "private-db"
    nat_gateway      = optional(bool, false)
    tags             = map(string)
  }))
}

variable "compliance_config" {
  description = "Compliance configuration for subnets"
  type = object({
    enforce_subnet_isolation = bool
    restrict_public_ip      = bool
    allowed_regions        = list(string)
    require_resource_tags  = bool
    mandatory_tags        = map(string)
  })
  default = {
    enforce_subnet_isolation = true
    restrict_public_ip      = true
    allowed_regions        = ["eu-west-1", "eu-central-1", "ap-south-1"]
    require_resource_tags  = true
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

variable "region" {
  type = string
}