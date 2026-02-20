output "cloudfront_domain" {
  description = "Public URL for the frontend (use this until you add a custom domain)."
  value       = "https://${aws_cloudfront_distribution.frontend.domain_name}"
}

output "api_endpoint" {
  description = "Base URL for the REST API."
  value       = "${aws_api_gateway_stage.main.invoke_url}"
}

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID (needed by the frontend SDK)."
  value       = aws_cognito_user_pool.main.id
}

output "cognito_client_id" {
  description = "Cognito App Client ID (needed by the frontend SDK)."
  value       = aws_cognito_user_pool_client.web.id
}

output "dynamodb_table_name" {
  description = "DynamoDB table that stores click events."
  value       = aws_dynamodb_table.click_log.name
}

output "s3_frontend_bucket" {
  description = "S3 bucket for deploying frontend assets."
  value       = aws_s3_bucket.frontend.bucket
}
