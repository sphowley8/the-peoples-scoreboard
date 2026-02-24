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

# Campaigns table — one campaign per user, named by the user.
resource "aws_dynamodb_table" "campaigns" {
  name         = "${var.project_name}-campaigns-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "campaign_id"

  attribute {
    name = "campaign_id"
    type = "S"
  }

  attribute {
    name = "owner_user_id"
    type = "S"
  }

  # GSI so we can look up a user's campaign by their Cognito sub
  global_secondary_index {
    name            = "owner_user_id-index"
    hash_key        = "owner_user_id"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name = "${var.project_name}-campaigns-${var.environment}"
  }
}

# Anonymous campaign click dedup — prevents double-clicks within the same browser session.
# PK: session_id (client-generated UUID) + button_id. TTL auto-expires after 24h.
resource "aws_dynamodb_table" "campaign_click_dedup" {
  name         = "${var.project_name}-campaign-click-dedup-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "session_id"
  range_key    = "button_id"

  attribute {
    name = "session_id"
    type = "S"
  }

  attribute {
    name = "button_id"
    type = "S"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name = "${var.project_name}-campaign-click-dedup-${var.environment}"
  }
}

# Deduplication table — enforces one click per user per button.
# Primary key: user_id (hash) + button_id (range) is unique by definition,
# so a conditional put_item will fail if the pair already exists.
resource "aws_dynamodb_table" "click_dedup" {
  name         = "${var.project_name}-click-dedup-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user_id"
  range_key    = "button_id"

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "button_id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name = "${var.project_name}-click-dedup-${var.environment}"
  }
}
