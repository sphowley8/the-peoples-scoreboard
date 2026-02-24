"""
Lambda: GET /leaderboard

Returns campaigns ranked by total actions, descending.
Scans the click-log table and groups by campaign_id.
Pre-feature entries without a campaign_id are grouped under "none".

Campaign display names come from the campaigns table.
"none" is displayed as "No Campaign".

No authentication required — public endpoint.
"""

import json
import os

import boto3
from boto3.dynamodb.conditions import Key

CLICK_LOG_TABLE  = os.environ["DYNAMODB_TABLE"]
CAMPAIGNS_TABLE  = os.environ["CAMPAIGNS_TABLE"]

dynamodb         = boto3.resource("dynamodb")
click_log_table  = dynamodb.Table(CLICK_LOG_TABLE)
campaigns_table  = dynamodb.Table(CAMPAIGNS_TABLE)


def handler(event, context):
    # Scan click-log, group by campaign_id
    counts: dict[str, int] = {}
    try:
        scan_kwargs: dict = {"ProjectionExpression": "campaign_id"}
        while True:
            resp = click_log_table.scan(**scan_kwargs)
            for item in resp.get("Items", []):
                cid = item.get("campaign_id", "none") or "none"
                counts[cid] = counts.get(cid, 0) + 1
            last = resp.get("LastEvaluatedKey")
            if not last:
                break
            scan_kwargs["ExclusiveStartKey"] = last
    except Exception:
        return _response(500, {"error": "Failed to fetch leaderboard data"})

    # Sort descending by count
    ranked = sorted(counts.items(), key=lambda x: x[1], reverse=True)

    # Batch-fetch campaign names for all non-"none" campaign IDs
    name_map: dict[str, str] = {}
    campaign_ids = [cid for cid, _ in ranked if cid != "none"]
    for cid in campaign_ids:
        try:
            resp = campaigns_table.get_item(Key={"campaign_id": cid})
            item = resp.get("Item")
            if item:
                name_map[cid] = item.get("campaign_name", f"Campaign {cid}")
        except Exception:
            name_map[cid] = f"Campaign {cid}"  # fallback

    # Build response rows
    rows = []
    for rank, (cid, count) in enumerate(ranked, start=1):
        if cid == "none":
            display = "No Campaign"
        else:
            display = name_map.get(cid, f"Campaign {cid}")
        rows.append({
            "rank":        rank,
            "campaign_id": cid,
            "display":     display,
            "actions":     count,
        })

    return _response(200, {"leaderboard": rows, "total_users": len(rows)})


def _response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
        },
        "body": json.dumps(body),
    }
