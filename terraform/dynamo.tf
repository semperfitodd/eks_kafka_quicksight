resource "aws_dynamodb_table" "log_analysis_table" {
  name         = "log_analysis"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "log_identifier"
  range_key    = "timestamp"

  attribute {
    name = "log_identifier"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "N"
  }

  global_secondary_index {
    name            = "rcf_score_index"
    hash_key        = "log_identifier"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }
}
