#!/usr/bin/env bash
# deploy-frontend.sh
# Syncs the frontend to S3 and invalidates the CloudFront cache.
# Run from anywhere — paths are relative to this script's directory.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRONTEND_DIR="$SCRIPT_DIR/frontend"
TERRAFORM_DIR="$SCRIPT_DIR/terraform"

# ── Resolve values from Terraform outputs ─────────────────────────────────────
echo "📦  Reading Terraform outputs..."
S3_BUCKET=$(terraform -chdir="$TERRAFORM_DIR" output -raw s3_frontend_bucket)
CF_DOMAIN=$(terraform -chdir="$TERRAFORM_DIR" output -raw cloudfront_domain)

# Get the CloudFront distribution ID by matching on the domain name
CF_DISTRIBUTION_ID=$(
  aws cloudfront list-distributions \
    --query "DistributionList.Items[?DomainName=='${CF_DOMAIN#https://}'].Id" \
    --output text
)

if [[ -z "$CF_DISTRIBUTION_ID" ]]; then
  echo "❌  Could not find a CloudFront distribution for domain: $CF_DOMAIN"
  exit 1
fi

# ── Sync to S3 ────────────────────────────────────────────────────────────────
echo ""
echo "🚀  Syncing frontend to s3://$S3_BUCKET ..."
aws s3 sync "$FRONTEND_DIR/" "s3://$S3_BUCKET/" \
  --delete \
  --cache-control "max-age=0,no-cache,no-store,must-revalidate"

# ── Invalidate CloudFront ──────────────────────────────────────────────────────
echo ""
echo "🔄  Invalidating CloudFront distribution $CF_DISTRIBUTION_ID ..."
INVALIDATION_ID=$(
  aws cloudfront create-invalidation \
    --distribution-id "$CF_DISTRIBUTION_ID" \
    --paths "/*" \
    --query "Invalidation.Id" \
    --output text
)

echo ""
echo "✅  Done!"
echo "    S3 bucket:        s3://$S3_BUCKET"
echo "    CloudFront:       $CF_DOMAIN"
echo "    Invalidation ID:  $INVALIDATION_ID"
echo ""
echo "    Changes will be live within ~30 seconds."
