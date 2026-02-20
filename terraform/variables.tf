variable "aws_region" {
  description = "AWS region for all resources (except us-east-1 ACM certs)."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment label (e.g. dev, staging, prod)."
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Short name prefix used in all resource names."
  type        = string
  default     = "peoples-scoreboard"
}

variable "domain_name" {
  description = "Custom domain for CloudFront (e.g. scoreboard.example.com). Leave empty to use the default CloudFront domain."
  type        = string
  default     = ""
}

