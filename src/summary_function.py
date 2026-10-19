import os
from collections import Counter
from datetime import datetime, timedelta, timezone

import boto3
from boto3.dynamodb.conditions import Attr

TABLE_NAME = os.environ.get("TABLE_NAME", "tickets")
TOPIC_ARN = os.environ["TOPIC_ARN"]
URGENCY_ORDER = ["critical", "high", "medium", "low"]


def fetch_recent_tickets(since):
    """Scan the table for tickets created after 'since', following pagination."""
    table = boto3.resource("dynamodb").Table(TABLE_NAME)
    kwargs = {"FilterExpression": Attr("created_at").gte(since)}
    items = []
    while True:
        page = table.scan(**kwargs)
        items.extend(page["Items"])
        if "LastEvaluatedKey" not in page:
            return items
        kwargs["ExclusiveStartKey"] = page["LastEvaluatedKey"]


def build_report(tickets, since):
    if not tickets:
        return "No tickets were received in the last 24 hours."

    by_category = Counter(t["category"] for t in tickets)
    by_urgency = Counter(t["urgency"] for t in tickets)

    lines = [
        "Support ticket summary",
        "Period: " + since + " to now (UTC)",
        "Total tickets: " + str(len(tickets)),
        "",
        "By urgency:",
    ]
    for level in URGENCY_ORDER:
        lines.append("  " + level + ": " + str(by_urgency.get(level, 0)))
    lines += ["", "By category:"]
    for name, count in by_category.most_common():
        lines.append("  " + name + ": " + str(count))

    urgent = [t for t in tickets if t["urgency"] in ("critical", "high")]
    if urgent:
        lines += ["", "Needs attention:"]
        for t in sorted(urgent, key=lambda x: x["created_at"]):
            lines.append("  [" + t["urgency"].upper() + "] " + t["summary"])
    return "\n".join(lines)


def lambda_handler(event, context):
    since = (datetime.now(timezone.utc) - timedelta(hours=24)).isoformat()
    tickets = fetch_recent_tickets(since)
    report = build_report(tickets, since)
    boto3.client("sns").publish(
        TopicArn=TOPIC_ARN,
        Subject="Daily support ticket summary",
        Message=report,
    )
    return {"tickets": len(tickets)}
