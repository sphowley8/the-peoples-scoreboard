terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }

  # Uncomment and configure once you have an S3 bucket for remote state.
  # backend "s3" {
  #   bucket         = "peoples-scoreboard-tfstate"
  #   key            = "infra/terraform.tfstate"
  #   region         = var.aws_region
  #   dynamodb_table = "peoples-scoreboard-tflock"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "peoples-scoreboard"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# ACM certificates for CloudFront must live in us-east-1 regardless of the
# primary region.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "peoples-scoreboard"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
