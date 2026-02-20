"""
Lambda: GET /leaderboard

Returns a ranked list of users by total actions (click count), descending.
Scans the dedup table to count actions per user_id.
User emails are resolved from Cognito where possible; falls back to anonymized IDs.
No authentication required — public endpoint.
"""

import json
import os

import boto3

DEDUP_TABLE_NAME = os.environ["DEDUP_TABLE"]
USER_POOL_ID     = os.environ.get("USER_POOL_ID", "")

dynamodb   = boto3.resource("dynamodb")
dedup_table = dynamodb.Table(DEDUP_TABLE_NAME)
cognito    = boto3.client("cognito-idp", region_name="us-east-1")


def _anonymize(user_id: str) -> str:
    """Return a stable short handle like 'User #a3f2'."""
    return "User #" + user_id[-4:]


def handler(event, context):
    # Scan the dedup table to get all (user_id, button_id) pairs
    counts: dict[str, int] = {}
    try:
        paginator_kwargs = {"TableName": DEDUP_TABLE_NAME}
        scan_kwargs: dict = {"ProjectionExpression": "user_id"}
        while True:
            resp = dedup_table.scan(**scan_kwargs)
            for item in resp.get("Items", []):
                uid = item.get("user_id")
                if uid:
                    counts[uid] = counts.get(uid, 0) + 1
            last = resp.get("LastEvaluatedKey")
            if not last:
                break
            scan_kwargs["ExclusiveStartKey"] = last
    except Exception as e:
        return _response(500, {"error": "Failed to fetch leaderboard data"})

    # Sort descending by count
    ranked = sorted(counts.items(), key=lambda x: x[1], reverse=True)

    # Resolve display names via Cognito (best-effort, batch in chunks of 100)
    email_map: dict[str, str] = {}
    if USER_POOL_ID and ranked:
        user_ids = [uid for uid, _ in ranked]
        # ListUsers can filter by sub but only one at a time; use a scan approach
        # Instead, fetch all users with a ListUsers scan (up to 60 per page)
        try:
            paginate_kwargs: dict = {
                "UserPoolId": USER_POOL_ID,
                "AttributesToGet": ["email", "sub"],
                "Limit": 60,
            }
            while True:
                resp = cognito.list_users(**paginate_kwargs)
                for u in resp.get("Users", []):
                    attrs = {a["Name"]: a["Value"] for a in u.get("Attributes", [])}
                    sub   = attrs.get("sub")
                    email = attrs.get("email", "")
                    if sub:
                        # Mask email: show first 2 chars + domain
                        if "@" in email:
                            local, domain = email.split("@", 1)
                            masked = local[:2] + "***@" + domain
                        else:
                            masked = _anonymize(sub)
                        email_map[sub] = masked
                token = resp.get("PaginationToken")
                if not token:
                    break
                paginate_kwargs["PaginationToken"] = token
        except Exception:
            pass  # fall back to anonymized IDs

    # Build response rows
    rows = []
    for rank, (uid, count) in enumerate(ranked, start=1):
        rows.append({
            "rank":    rank,
            "display": email_map.get(uid, _anonymize(uid)),
            "actions": count,
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
