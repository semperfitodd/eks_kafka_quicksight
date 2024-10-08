module "lambda_function_sagemaker" {
  source = "terraform-aws-modules/lambda/aws"

  function_name = var.environment
  description   = "${local.environment} function to authorize api gateway"
  handler       = "app.lambda_handler"
  publish       = true
  runtime       = "python3.11"
  timeout       = 30

  create_package = true

  environment_variables = {
    DYNAMO_TABLE_NAME  = aws_dynamodb_table.log_analysis_table.name
    SAGEMAKER_ENDPOINT = "todd-rcf"
  }

  source_path = [
    {
      path             = "${path.module}/lambda"
      pip_requirements = false
    }
  ]

  attach_policies = true
  policies        = ["arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"]

  attach_policy_statements = true
  policy_statements = {
    dynamo = {
      effect = "Allow",
      actions = [
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:GetItem",
      ]
      resources = [aws_dynamodb_table.log_analysis_table.arn]
    }
  }

  cloudwatch_logs_retention_in_days = 3

  tags = var.tags
}
