data "aws_iam_policy_document" "app" {
  statement {
    effect  = "Allow"
    actions = ["s3:Get*", "s3:List*"]
    principals {
      identifiers = ["*"]
      type        = "*"
    }
    resources = [
      module.app_s3_bucket.s3_bucket_arn,
      "${module.app_s3_bucket.s3_bucket_arn}/*",
    ]
  }
}

module "app_s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 4.1.2"

  bucket = "${local.environment}-app-${random_string.this.result}"

  attach_public_policy = true
  attach_policy        = true
  policy               = data.aws_iam_policy_document.app.json

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false

  control_object_ownership = true
  object_ownership         = "ObjectWriter"

  expected_bucket_owner = data.aws_caller_identity.current.account_id

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  lifecycle_rule = [{
    id      = "expire-objects"
    enabled = true

    expiration = {
      days = 1
    }
  }]

  tags = var.tags
}

resource "random_string" "this" {
  length = 4

  lower   = true
  numeric = true
  special = false
  upper   = false
}
