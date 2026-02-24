"""
Lambda: POST /log-campaign-click

Public endpoint (no auth). Records an action attributed to a campaign.
Called by anonymous visitors who arrived via a campaign share link.

Body (JSON):
  {
    "button_id":   "amazon-prime",
    "target_url":  "https://...",
    "campaign_id": "abc12345",
    "session_id":  "uuid-generated-client-side"
  }

Dedup: one click per (session_id, button_id) per 24-hour window.
The session_id is a UUID stored in the visitor's sessionStorage — it
prevents accidental double-clicks in the same session but is not a
hard anti-abuse measure.

Returns 409 if already clicked in this session.
Returns 400 if campaign_id does not exist in the campaigns table.
"""

import json
import os
import uuid
from datetime import datetime, timezone

import boto3
from boto3.dynamodb.conditions import Attr
from botocore.exceptions import ClientError

CLICK_LOG_TABLE      = os.environ["DYNAMODB_TABLE"]
CAMPAIGNS_TABLE      = os.environ["CAMPAIGNS_TABLE"]
CAMPAIGN_DEDUP_TABLE = os.environ["CAMPAIGN_DEDUP_TABLE"]

dynamodb             = boto3.resource("dynamodb")
click_log_table      = dynamodb.Table(CLICK_LOG_TABLE)
campaigns_table      = dynamodb.Table(CAMPAIGNS_TABLE)
campaign_dedup_table = dynamodb.Table(CAMPAIGN_DEDUP_TABLE)


def handler(event, context):
    # Parse body
    try:
        body       = json.loads(event.get("body") or "{}")
        button_id  = body["button_id"]
        campaign_id = body["campaign_id"]
        session_id  = body["session_id"]
        target_url  = body.get("target_url", "")
    except (json.JSONDecodeError, KeyError):
        return _response(400, {"error": "Invalid request body. Required: button_id, campaign_id, session_id"})

    # Validate inputs
    if not campaign_id or not session_id or not button_id:
        return _response(400, {"error": "button_id, campaign_id, and session_id are required"})

    # Validate campaign exists
    try:
        resp = campaigns_table.get_item(Key={"campaign_id": campaign_id})
        if "Item" not in resp:
            return _response(400, {"error": "Campaign not found"})
    except Exception:
        return _response(500, {"error": "Failed to validate campaign"})

    timestamp = datetime.now(timezone.utc).isoformat()
    ttl_value = int(datetime.now(timezone.utc).timestamp()) + 86400  # 24h TTL

    # Dedup check — one click per (session_id, button_id) per session
    try:
        campaign_dedup_table.put_item(
            Item={
                "session_id": session_id,
                "button_id":  button_id,
                "ttl":        ttl_value,
                "timestamp":  timestamp,
            },
            ConditionExpression=(
                Attr("session_id").not_exists() & Attr("button_id").not_exists()
            ),
        )
    except ClientError as e:
        if e.response["Error"]["Code"] == "ConditionalCheckFailedException":
            return _response(409, {"error": "Already clicked", "button_id": button_id})
        raise

    # Write to click log
    click_log_table.put_item(
        Item={
            "user_id":     "anonymous",
            "timestamp":   timestamp,
            "button_id":   button_id,
            "target_url":  target_url,
            "campaign_id": campaign_id,
            "session_id":  session_id,
            "event_id":    str(uuid.uuid4()),
        }
    )

    return _response(200, {"message": "logged", "timestamp": timestamp})


def _response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
        },
        "body": json.dumps(body),
    }
