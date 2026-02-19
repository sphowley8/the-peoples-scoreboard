"""
Lambda: GET /user-activity

Returns the authenticated user's click history, sorted newest-first.
Cognito authorizer injects the caller's sub into requestContext.
Query params:
  limit  (optional) — max number of items to return, default 20
"""

import json
import os

import boto3
from boto3.dynamodb.conditions import Key

TABLE_NAME = os.environ["DYNAMODB_TABLE"]
dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(TABLE_NAME)


def handler(event, context):
    # Auth
    try:
        claims = event["requestContext"]["authorizer"]["claims"]
        user_id = claims["sub"]
    except (KeyError, TypeError):
        return _response(401, {"error": "Unauthorized"})

    # Optional limit param
    try:
        limit = int(
            (event.get("queryStringParameters") or {}).get("limit", 20)
        )
        limit = max(1, min(limit, 100))  # clamp between 1 and 100
    except (ValueError, TypeError):
        limit = 20

    try:
        result = table.query(
            KeyConditionExpression=Key("user_id").eq(user_id),
            ScanIndexForward=False,  # newest first
            Limit=limit,
        )
        items = result.get("Items", [])

        return _response(200, {
            "items": items,
            "count": len(items),
        })

    except Exception as e:
        return _response(500, {"error": "Internal server error"})


def _response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
        },
        "body": json.dumps(body),
    }
