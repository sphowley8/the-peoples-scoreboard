# --- S3 bucket for static site assets ---

resource "aws_s3_bucket" "frontend" {
  bucket = "${var.project_name}-frontend-${var.environment}-${data.aws_caller_identity.current.account_id}"
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket                  = aws_s3_bucket.frontend.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# --- CloudFront Origin Access Control ---

resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "${var.project_name}-oac-${var.environment}"
  description                       = "OAC for ${var.project_name} frontend"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# --- ACM certificate (must be in us-east-1 for CloudFront) ---

resource "aws_acm_certificate" "frontend" {
  count    = var.domain_name != "" ? 1 : 0
  provider = aws.us_east_1

  domain_name               = var.domain_name
  subject_alternative_names = ["www.${var.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# --- CloudFront cache policies ---

# Public read-only API responses (click-count, leaderboard).
# These are safe to cache at the edge — no auth, no user-specific data.
resource "aws_cloudfront_cache_policy" "click_count" {
  name        = "${var.project_name}-click-count-${var.environment}"
  comment     = "60s cache for /click-count — keyed on button_id query string"
  default_ttl = 60
  min_ttl     = 0
  max_ttl     = 60

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config  { cookie_behavior = "none" }
    headers_config  { header_behavior = "none" }
    query_strings_config {
      query_string_behavior = "whitelist"
      query_strings { items = ["button_id"] }
    }
    enable_accept_encoding_gzip   = true
    enable_accept_encoding_brotli = true
  }
}

resource "aws_cloudfront_cache_policy" "leaderboard" {
  name        = "${var.project_name}-leaderboard-${var.environment}"
  comment     = "5min cache for /leaderboard"
  default_ttl = 300
  min_ttl     = 0
  max_ttl     = 300

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config  { cookie_behavior = "none" }
    headers_config  { header_behavior = "none" }
    query_strings_config { query_string_behavior = "none" }
    enable_accept_encoding_gzip   = true
    enable_accept_encoding_brotli = true
  }
}

# Origin request policy for public endpoints (click-count, leaderboard).
# No Authorization needed — just forward query strings.
resource "aws_cloudfront_origin_request_policy" "api_public" {
  name    = "${var.project_name}-api-public-${var.environment}"
  comment = "Forward query strings to API Gateway for public endpoints"

  cookies_config       { cookie_behavior = "none" }
  headers_config       { header_behavior = "none" }
  query_strings_config { query_string_behavior = "all" }
}


# --- CloudFront distribution ---

resource "aws_cloudfront_distribution" "frontend" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100" # US, Canada, Europe only — cheapest

  aliases = var.domain_name != "" ? [var.domain_name, "www.${var.domain_name}"] : []

  # Origin 1 — S3 static files
  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "s3-frontend"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  # Origin 2 — API Gateway (regional, HTTPS only)
  origin {
    domain_name = "${aws_api_gateway_rest_api.main.id}.execute-api.${var.aws_region}.amazonaws.com"
    origin_id   = "api-gateway"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }

    origin_path = "/${var.environment}"
  }

  # ── Cached public endpoints ──────────────────────────────────────────────────

  # GET /click-count?button_id=... → 60s cache, keyed on button_id
  ordered_cache_behavior {
    path_pattern           = "/click-count*"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "api-gateway"
    viewer_protocol_policy = "https-only"
    compress               = true
    cache_policy_id          = aws_cloudfront_cache_policy.click_count.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.api_public.id
  }

  # GET /leaderboard → 5min cache
  ordered_cache_behavior {
    path_pattern           = "/leaderboard*"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "api-gateway"
    viewer_protocol_policy = "https-only"
    compress               = true
    cache_policy_id          = aws_cloudfront_cache_policy.leaderboard.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.api_public.id
  }

  # ── Pass-through for auth-required / POST endpoints ──────────────────────────
  # Uses AWS managed CachingDisabled policy (4135ea2d-...) — never caches,
  # and allows the origin request policy to forward Authorization freely.

  ordered_cache_behavior {
    path_pattern           = "/log-click*"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "PATCH", "POST", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "api-gateway"
    viewer_protocol_policy = "https-only"
    compress               = true
    # AWS managed CachingDisabled policy
    cache_policy_id          = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    # AWS managed AllViewerExceptHostHeader — forwards all viewer headers
    # including Authorization, but excludes Host (required for API GW).
    origin_request_policy_id = "b689b0a8-53d0-40ab-baf2-68738e2966ac"
  }

  ordered_cache_behavior {
    path_pattern           = "/user-activity*"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "api-gateway"
    viewer_protocol_policy = "https-only"
    compress               = true
    cache_policy_id          = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    # AWS managed AllViewerExceptHostHeader — forwards all viewer headers
    # including Authorization, but excludes Host (required for API GW).
    origin_request_policy_id = "b689b0a8-53d0-40ab-baf2-68738e2966ac"
  }

  ordered_cache_behavior {
    path_pattern           = "/user-votes*"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "api-gateway"
    viewer_protocol_policy = "https-only"
    compress               = true
    cache_policy_id          = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    # AWS managed AllViewerExceptHostHeader — forwards all viewer headers
    # including Authorization, but excludes Host (required for API GW).
    origin_request_policy_id = "b689b0a8-53d0-40ab-baf2-68738e2966ac"
  }

  # ── Default — S3 static files ────────────────────────────────────────────────

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-frontend"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  # Return index.html for any 403/404 so the SPA router handles routing.
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    # Use the ACM cert if a custom domain is supplied, otherwise use the
    # default *.cloudfront.net certificate.
    acm_certificate_arn      = var.domain_name != "" ? aws_acm_certificate.frontend[0].arn : null
    cloudfront_default_certificate = var.domain_name == "" ? true : false
    ssl_support_method       = var.domain_name != "" ? "sni-only" : null
    minimum_protocol_version = var.domain_name != "" ? "TLSv1.2_2021" : null
  }
}

# --- S3 bucket policy: allow CloudFront OAC only ---

resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowCloudFrontServicePrincipal"
      Effect = "Allow"
      Principal = {
        Service = "cloudfront.amazonaws.com"
      }
      Action   = "s3:GetObject"
      Resource = "${aws_s3_bucket.frontend.arn}/*"
      Condition = {
        StringEquals = {
          "AWS:SourceArn" = aws_cloudfront_distribution.frontend.arn
        }
      }
    }]
  })
}
