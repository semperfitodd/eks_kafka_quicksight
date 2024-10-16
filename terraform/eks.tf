data "aws_caller_identity" "current" {}

data "aws_iam_policy" "AmazonSSMManagedInstanceCore" {
  name = "AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "s3_eks" {
  statement {
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${module.app_s3_bucket.s3_bucket_arn}/*"]
  }
}

locals {
  assumed_role_arn = data.aws_caller_identity.current.arn
  account_id       = data.aws_caller_identity.current.account_id
  role_name        = regex("arn:aws:sts::\\d+:assumed-role/(.+?)/", local.assumed_role_arn)[0]
  iam_role_arn     = "arn:aws:iam::${local.account_id}:role/${local.role_name}"
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.11.1"

  cluster_name = local.environment

  authentication_mode             = "API_AND_CONFIG_MAP"
  cluster_version                 = var.eks_cluster_version
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  cluster_ip_family = "ipv4"

  cluster_addons = {
    aws-ebs-csi-driver = {
      service_account_role_arn = module.ebs_csi_irsa_role.iam_role_arn
      most_recent              = true
    }
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent    = true
      before_compute = true
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
  }

  iam_role_additional_policies = {
    AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  }

  enable_cluster_creator_admin_permissions = true

  cluster_tags = var.tags

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_group_defaults = {
    ami_type       = "AL2_x86_64"
    instance_types = [var.eks_node_instance_type]
  }

  eks_managed_node_groups = {
    node_group = {
      ami_type = "AL2_x86_64"

      min_size     = 1
      max_size     = 5
      desired_size = 3

      use_latest_ami_release_version = true

      ebs_optimized     = true
      enable_monitoring = true

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 75
            volume_type           = "gp3"
            encrypted             = true
            delete_on_termination = true
          }
        }
      }

      iam_role_additional_policies = {
        AmazonSSMManagedInstanceCore = data.aws_iam_policy.AmazonSSMManagedInstanceCore.arn
        s3_eks                       = aws_iam_policy.s3_eks.arn
      }

      tags = var.tags
    }
  }
}

resource "aws_iam_policy" "s3_eks" {
  name        = "${var.environment}_s3_eks"
  description = "EKS to S3 put permissions"
  policy      = data.aws_iam_policy_document.s3_eks.json
}

module "ebs_csi_irsa_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name             = "${var.environment}_ebs_csi"
  attach_ebs_csi_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}
