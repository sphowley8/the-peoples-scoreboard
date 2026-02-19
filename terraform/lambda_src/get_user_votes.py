"""
Lambda: GET /user-votes

Returns the list of button_ids the authenticated user has already voted on.
Queries the dedup table by user_id so the frontend can disable already-clicked buttons.
"""

import json
import os

import boto3
from boto3.dynamodb.conditions import Key

DEDUP_TABLE_NAME = os.environ["DEDUP_TABLE"]
dynamodb         = boto3.resource("dynamodb")
dedup_table      = dynamodb.Table(DEDUP_TABLE_NAME)


def handler(event, context):
    # Auth
    try:
        claims  = event["requestContext"]["authorizer"]["claims"]
        user_id = claims["sub"]
    except (KeyError, TypeError):
        return _response(401, {"error": "Unauthorized"})

    try:
        result     = dedup_table.query(
            KeyConditionExpression=Key("user_id").eq(user_id),
            ProjectionExpression="button_id",
        )
        button_ids = [item["button_id"] for item in result.get("Items", [])]

        # Handle pagination
        while "LastEvaluatedKey" in result:
            result = dedup_table.query(
                KeyConditionExpression=Key("user_id").eq(user_id),
                ProjectionExpression="button_id",
                ExclusiveStartKey=result["LastEvaluatedKey"],
            )
            button_ids += [item["button_id"] for item in result.get("Items", [])]

        return _response(200, {"voted_buttons": button_ids})

    except Exception:
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
