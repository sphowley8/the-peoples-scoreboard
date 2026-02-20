resource "aws_cognito_user_pool" "main" {
  name = "${var.project_name}-users-${var.environment}"

  # Email is both the username and the OTP delivery channel.
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  # EMAIL_OTP is the intended auth method. AWS requires PASSWORD to be listed
  # alongside it, but the app client does not include ALLOW_USER_PASSWORD_AUTH
  # so passwords cannot actually be used to sign in.
  sign_in_policy {
    allowed_first_auth_factors = ["EMAIL_OTP", "PASSWORD"]
  }

  # Use Cognito's built-in mailer for OTP delivery (fine for MVP).
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
    email_subject        = "Your People's Scoreboard sign-in code"
    email_message        = "Your one-time sign-in code is {####}. It expires in 15 minutes."
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
  name         = "${var.project_name}-web-client-${var.environment}"
  user_pool_id = aws_cognito_user_pool.main.id

  generate_secret = false # SPA — no secret possible in the browser.

  # ALLOW_USER_AUTH enables the USER_AUTH flow required for EMAIL_OTP.
  # ALLOW_REFRESH_TOKEN_AUTH lets the frontend refresh sessions silently.
  explicit_auth_flows = [
    "ALLOW_USER_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]

  # No Hosted UI / OAuth — auth is handled entirely in login.html.
  allowed_oauth_flows_user_pool_client = false

  prevent_user_existence_errors = "LEGACY"
  enable_token_revocation       = true

  access_token_validity  = 1  # hours
  id_token_validity      = 1  # hours
  refresh_token_validity = 30 # days

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }
}
