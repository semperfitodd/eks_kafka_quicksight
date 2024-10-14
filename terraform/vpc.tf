data "aws_availability_zones" "main" {}

locals {
  availability_zones = [
    data.aws_availability_zones.main.names[0],
    data.aws_availability_zones.main.names[1],
    data.aws_availability_zones.main.names[2],
  ]

  public_subnets = [
    cidrsubnet(var.vpc_cidr, 6, 0),
    cidrsubnet(var.vpc_cidr, 6, 1),
    cidrsubnet(var.vpc_cidr, 6, 2),
  ]

  private_subnets = [
    cidrsubnet(var.vpc_cidr, 6, 4),
    cidrsubnet(var.vpc_cidr, 6, 5),
    cidrsubnet(var.vpc_cidr, 6, 6),
  ]

  database_subnets = [
    cidrsubnet(var.vpc_cidr, 6, 7),
    cidrsubnet(var.vpc_cidr, 6, 8),
    cidrsubnet(var.vpc_cidr, 6, 9),
  ]

  vpc_route_tables = flatten([
    module.vpc.private_route_table_ids,
    module.vpc.public_route_table_ids,
  ])
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.8.1"

  azs                                             = local.availability_zones
  cidr                                            = var.vpc_cidr
  create_database_subnet_group                    = true
  create_flow_log_cloudwatch_iam_role             = true
  create_flow_log_cloudwatch_log_group            = true
  database_subnets                                = local.database_subnets
  enable_dhcp_options                             = true
  enable_dns_hostnames                            = true
  enable_dns_support                              = true
  enable_flow_log                                 = true
  enable_nat_gateway                              = true
  flow_log_cloudwatch_log_group_retention_in_days = 7
  flow_log_max_aggregation_interval               = 60
  name                                            = var.environment
  one_nat_gateway_per_az                          = var.vpc_redundancy ? true : false
  private_subnet_suffix                           = "private"
  private_subnets                                 = local.private_subnets
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  public_subnets = local.public_subnets
  public_subnet_tags = {
    "kubernetes.io/cluster/${module.eks.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                           = 1
  }

  single_nat_gateway = var.vpc_redundancy ? false : true
  tags               = var.tags
}

module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "~> 5.8.1"

  vpc_id = module.vpc.vpc_id
  tags   = var.tags

  endpoints = {
    s3 = {
      route_table_ids = local.vpc_route_tables
      service         = "s3"
      service_type    = "Gateway"
      tags            = { Name = "s3-vpc-endpoint" }
    }
  }
}