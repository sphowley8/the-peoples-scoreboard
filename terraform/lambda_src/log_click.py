"""
Lambda: POST /log-click

Expects a Cognito-authorised request. API Gateway injects the caller's
sub (unique user ID) into requestContext.authorizer.claims.sub.

Body (JSON):
  { "button_id": "unsubscribe", "target_url": "https://..." }

Each user may only click each button once. A second click for the same
(user_id, button_id) pair returns 409 Already Voted.
"""

import json
import os
import uuid
from datetime import datetime, timezone

import boto3
from boto3.dynamodb.conditions import Attr
from botocore.exceptions import ClientError

TABLE_NAME       = os.environ["DYNAMODB_TABLE"]
DEDUP_TABLE_NAME = os.environ["DEDUP_TABLE"]

dynamodb    = boto3.resource("dynamodb")
table       = dynamodb.Table(TABLE_NAME)
dedup_table = dynamodb.Table(DEDUP_TABLE_NAME)


def handler(event, context):
    # Auth
    try:
        claims  = event["requestContext"]["authorizer"]["claims"]
        user_id = claims["sub"]
    except (KeyError, TypeError):
        return _response(401, {"error": "Unauthorized"})

    # Parse body
    try:
        body        = json.loads(event.get("body") or "{}")
        button_id   = body["button_id"]
        target_url  = body.get("target_url", "")
        campaign_id = body.get("campaign_id", "none")  # optional, defaults to "none"
    except (json.JSONDecodeError, KeyError):
        return _response(400, {"error": "Invalid request body"})

    timestamp = datetime.now(timezone.utc).isoformat()

    # Atomic dedup check — fails if (user_id, button_id) already exists
    try:
        dedup_table.put_item(
            Item={
                "user_id":   user_id,
                "button_id": button_id,
                "timestamp": timestamp,
            },
            ConditionExpression=(
                Attr("user_id").not_exists() & Attr("button_id").not_exists()
            ),
        )
    except ClientError as e:
        if e.response["Error"]["Code"] == "ConditionalCheckFailedException":
            return _response(409, {"error": "Already voted", "button_id": button_id})
        raise

    # Write to the main click log
    table.put_item(
        Item={
            "user_id":     user_id,
            "timestamp":   timestamp,
            "button_id":   button_id,
            "target_url":  target_url,
            "campaign_id": campaign_id,
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
