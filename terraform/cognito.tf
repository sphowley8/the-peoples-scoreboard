resource "aws_cognito_user_pool" "main" {
  name = "${var.project_name}-users-${var.environment}"

  # Allow users to sign in with their email address.
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length                   = 8
    require_lowercase                = true
    require_uppercase                = true
    require_numbers                  = true
    require_symbols                  = false
    temporary_password_validity_days = 7
  }

  # Send verification emails via Cognito's built-in mailer (fine for MVP).
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
    email_subject        = "Your People's Scoreboard verification code"
    email_message        = "Your verification code is {####}"
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }
}

# App client used by the frontend (no client secret — SPA can't keep secrets).
resource "aws_cognito_user_pool_client" "web" {
  name                                 = "${var.project_name}-web-client-${var.environment}"
  user_pool_id                         = aws_cognito_user_pool.main.id
  generate_secret                      = false
  prevent_user_existence_errors        = "ENABLED"
  enable_token_revocation              = true
  allowed_oauth_flows_user_pool_client = true

  allowed_oauth_flows  = ["code"]
  allowed_oauth_scopes = ["openid", "email", "profile"]

  callback_urls = var.cognito_callback_urls
  logout_urls   = var.cognito_logout_urls

  supported_identity_providers = ["COGNITO"]

  # Token validity
  access_token_validity  = 1   # hours
  id_token_validity      = 1   # hours
  refresh_token_validity = 30  # days

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }
}

# Hosted UI domain (e.g. https://<prefix>.auth.<region>.amazoncognito.com)
resource "aws_cognito_user_pool_domain" "main" {
  domain       = "${var.project_name}-${var.environment}"
  user_pool_id = aws_cognito_user_pool.main.id
}
