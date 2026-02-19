"""
Lambda: GET /click-count

Returns the total number of unique clicks for a given button.
Uses the button_id-index GSI to query by button_id without a full table scan.
No authentication required — this is public data.

Query params:
  button_id  (required) — e.g. "unsubscribe"
"""

import json
import os

import boto3
from boto3.dynamodb.conditions import Key

TABLE_NAME = os.environ["DYNAMODB_TABLE"]
dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(TABLE_NAME)


def handler(event, context):
    # Read button_id from query string
    params    = event.get("queryStringParameters") or {}
    button_id = params.get("button_id", "unsubscribe")

    try:
        result = table.query(
            IndexName="button_id-index",
            KeyConditionExpression=Key("button_id").eq(button_id),
            Select="COUNT",
        )
        count = result.get("Count", 0)

        # Handle pagination — DynamoDB returns up to 1MB per call
        while "LastEvaluatedKey" in result:
            result = table.query(
                IndexName="button_id-index",
                KeyConditionExpression=Key("button_id").eq(button_id),
                Select="COUNT",
                ExclusiveStartKey=result["LastEvaluatedKey"],
            )
            count += result.get("Count", 0)

        return _response(200, {"button_id": button_id, "count": count})

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
