#!/usr/bin/env bash
# teardown.sh — destroy all People's Scoreboard AWS infrastructure
#
# Usage:
#   ./scripts/teardown.sh [--auto-approve]
#
# Pass --auto-approve to skip the confirmation prompt (useful in CI).
# Without it, you'll be shown a plan and asked to confirm.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="$SCRIPT_DIR/../terraform"

AUTO_APPROVE=false
for arg in "$@"; do
  [[ "$arg" == "--auto-approve" ]] && AUTO_APPROVE=true
done

echo ""
echo "======================================================"
echo "  People's Scoreboard — Infrastructure Teardown"
echo "======================================================"
echo ""
echo "Terraform directory : $TF_DIR"
echo ""

# Confirm unless --auto-approve was passed.
if [[ "$AUTO_APPROVE" == false ]]; then
  read -r -p "This will DESTROY all AWS resources. Are you sure? [y/N] " confirm
  echo ""
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
  fi
fi

cd "$TF_DIR"

# ---------------------------------------------------------------
# 1. Empty the S3 frontend bucket before destroy.
#    CloudFormation / Terraform cannot delete a non-empty bucket.
# ---------------------------------------------------------------
BUCKET=$(terraform output -raw s3_frontend_bucket 2>/dev/null || true)

if [[ -n "$BUCKET" ]]; then
  echo ">> Emptying S3 bucket: $BUCKET"
  # Delete all object versions (needed if versioning is enabled).
  aws s3api list-object-versions \
    --bucket "$BUCKET" \
    --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' \
    --output json 2>/dev/null \
  | jq -r '.Objects // [] | .[] | "\(.Key) \(.VersionId)"' \
  | while read -r key version; do
      aws s3api delete-object \
        --bucket "$BUCKET" \
        --key "$key" \
        --version-id "$version" \
        --output text > /dev/null
    done

  # Delete any delete-markers left behind.
  aws s3api list-object-versions \
    --bucket "$BUCKET" \
    --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' \
    --output json 2>/dev/null \
  | jq -r '.Objects // [] | .[] | "\(.Key) \(.VersionId)"' \
  | while read -r key version; do
      aws s3api delete-object \
        --bucket "$BUCKET" \
        --key "$key" \
        --version-id "$version" \
        --output text > /dev/null
    done

  echo "   Bucket emptied."
fi

# ---------------------------------------------------------------
# 2. Run terraform destroy.
# ---------------------------------------------------------------
echo ""
echo ">> Running terraform destroy..."
echo ""

if [[ "$AUTO_APPROVE" == true ]]; then
  terraform destroy -auto-approve
else
  terraform destroy
fi

echo ""
echo "======================================================"
echo "  Teardown complete. All resources have been removed."
echo "======================================================"
