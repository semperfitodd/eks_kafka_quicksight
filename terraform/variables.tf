locals {
  environment = replace(var.environment, "_", "-")
}

variable "eks_cluster_version" {
  description = "Version of kubernetes running on cluster"
  type        = string

  default = ""
}

variable "eks_node_instance_type" {
  description = "Instance type for EKS worker node managed group"
  type        = string

  default = ""
}

variable "environment" {
  description = "Environment name"
  type        = string

  default = ""
}

variable "region" {
  description = "AWS region"
  type        = string

  default = ""
}

variable "tags" {
  description = "Universal tags"
  type        = map(string)

  default = {}
}

variable "vpc_cidr" {
  description = "VPC cidr block"
  type        = string

  default = ""
}

variable "vpc_redundancy" {
  description = "Redundancy for this VPCs NAT gateways"
  type        = bool

  default = false
}
