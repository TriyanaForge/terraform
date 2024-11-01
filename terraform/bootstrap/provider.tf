# terraform/bootstrap/provider.tf

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# For primary bucket
provider "aws" {
  region = var.primary_region
}

# For replica bucket
provider "aws" {
  alias  = "replica"
  region = var.replica_region
}