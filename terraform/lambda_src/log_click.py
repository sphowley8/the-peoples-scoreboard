"""
Lambda: POST /log-click

Expects a Cognito-authorised request. API Gateway injects the caller's
sub (unique user ID) into requestContext.authorizer.claims.sub.

Body (JSON):
  { "button_id": "unsubscribe", "target_url": "https://..." }
"""

import json
import os
import uuid
from datetime import datetime, timezone

import boto3

TABLE_NAME = os.environ["DYNAMODB_TABLE"]
dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(TABLE_NAME)


def handler(event, context):
    try:
        claims = event["requestContext"]["authorizer"]["claims"]
        user_id = claims["sub"]
    except (KeyError, TypeError):
        return _response(401, {"error": "Unauthorized"})

    try:
        body = json.loads(event.get("body") or "{}")
        button_id = body["button_id"]
        target_url = body.get("target_url", "")
    except (json.JSONDecodeError, KeyError):
        return _response(400, {"error": "Invalid request body"})

    timestamp = datetime.now(timezone.utc).isoformat()

    table.put_item(
        Item={
            "user_id": user_id,
            "timestamp": timestamp,
            "button_id": button_id,
            "target_url": target_url,
            "event_id": str(uuid.uuid4()),
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
