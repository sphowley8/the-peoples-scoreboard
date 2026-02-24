"""
Lambda: POST /campaign  — create a campaign (auth required)
        GET  /campaign  — fetch the caller's campaign (auth required)

A user may have at most one campaign. POST is idempotent — if the user
already has a campaign it is returned unchanged.

POST body (JSON):
  { "campaign_name": "My Boycott Squad" }   # max 32 chars

GET response (200):
  { "campaign_id": "abc12345", "campaign_name": "My Boycott Squad", "share_url": "https://..." }

GET response (404):
  { "error": "No campaign found" }
"""

import json
import os
import random
import string
from datetime import datetime, timezone

import boto3
from boto3.dynamodb.conditions import Key

CAMPAIGNS_TABLE = os.environ["CAMPAIGNS_TABLE"]
APP_BASE        = os.environ.get("APP_BASE", "https://dmmywcvdfo0fv.cloudfront.net")
MAX_NAME_LEN    = 32

dynamodb        = boto3.resource("dynamodb")
campaigns_table = dynamodb.Table(CAMPAIGNS_TABLE)


def _generate_campaign_id(length: int = 8) -> str:
    """Generate a short random alphanumeric campaign ID."""
    chars = string.ascii_lowercase + string.digits
    return "".join(random.choices(chars, k=length))


def _get_user_campaign(owner_user_id: str):
    """Look up an existing campaign by owner via GSI. Returns item or None."""
    resp = campaigns_table.query(
        IndexName="owner_user_id-index",
        KeyConditionExpression=Key("owner_user_id").eq(owner_user_id),
        Limit=1,
    )
    items = resp.get("Items", [])
    return items[0] if items else None


def _share_url(campaign_id: str, campaign_name: str) -> str:
    from urllib.parse import quote
    return f"{APP_BASE}/?ref={campaign_id}&name={quote(campaign_name)}"


def handler(event, context):
    # Extract caller's user_id from Cognito claims
    try:
        claims      = event["requestContext"]["authorizer"]["claims"]
        owner_user_id = claims["sub"]
    except (KeyError, TypeError):
        return _response(401, {"error": "Unauthorized"})

    method = event.get("httpMethod", "GET")

    # ── GET /campaign ────────────────────────────────────────────────────────
    if method == "GET":
        try:
            item = _get_user_campaign(owner_user_id)
        except Exception:
            return _response(500, {"error": "Failed to fetch campaign"})

        if not item:
            return _response(404, {"error": "No campaign found"})

        return _response(200, {
            "campaign_id":   item["campaign_id"],
            "campaign_name": item["campaign_name"],
            "share_url":     _share_url(item["campaign_id"], item["campaign_name"]),
        })

    # ── POST /campaign ───────────────────────────────────────────────────────
    if method == "POST":
        # Parse and validate name
        try:
            body          = json.loads(event.get("body") or "{}")
            campaign_name = str(body.get("campaign_name", "")).strip()
        except json.JSONDecodeError:
            return _response(400, {"error": "Invalid request body"})

        if not campaign_name:
            return _response(400, {"error": "campaign_name is required"})
        if len(campaign_name) > MAX_NAME_LEN:
            return _response(400, {"error": f"campaign_name must be {MAX_NAME_LEN} characters or fewer"})

        # Idempotent — return existing campaign if user already has one
        try:
            existing = _get_user_campaign(owner_user_id)
        except Exception:
            return _response(500, {"error": "Failed to check existing campaigns"})

        if existing:
            return _response(200, {
                "campaign_id":   existing["campaign_id"],
                "campaign_name": existing["campaign_name"],
                "share_url":     _share_url(existing["campaign_id"], existing["campaign_name"]),
            })

        # Create new campaign
        campaign_id = _generate_campaign_id()
        timestamp   = datetime.now(timezone.utc).isoformat()

        try:
            campaigns_table.put_item(Item={
                "campaign_id":   campaign_id,
                "owner_user_id": owner_user_id,
                "campaign_name": campaign_name,
                "created_at":    timestamp,
            })
        except Exception:
            return _response(500, {"error": "Failed to create campaign"})

        return _response(200, {
            "campaign_id":   campaign_id,
            "campaign_name": campaign_name,
            "share_url":     _share_url(campaign_id, campaign_name),
        })

    return _response(405, {"error": f"Method {method} not allowed"})


def _response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
        },
        "body": json.dumps(body),
    }
