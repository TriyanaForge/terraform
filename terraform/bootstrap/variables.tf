# In variables.tf
variable "resource_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "tf"
}
variable "primary_region" {
  description = "Primary region for resources"
  type        = string
  default     = "ap-south-1"
}

variable "replica_region" {
  description = "Region for replica bucket"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "project" {
  description = "Project name"
  type        = string
  default     = "TriyanaForge"
}