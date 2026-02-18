resource "aws_dynamodb_table" "click_log" {
  name         = "${var.project_name}-click-log-${var.environment}"
  billing_mode = "PAY_PER_REQUEST" # no capacity planning required
  hash_key     = "user_id"
  range_key    = "timestamp"

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  attribute {
    name = "button_id"
    type = "S"
  }

  # GSI so you can query "how many clicks for button X?" without scanning the full table
  global_secondary_index {
    name            = "button_id-index"
    hash_key        = "button_id"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name = "${var.project_name}-click-log-${var.environment}"
  }
}
