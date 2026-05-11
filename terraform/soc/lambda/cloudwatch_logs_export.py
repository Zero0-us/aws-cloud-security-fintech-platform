import json
import os
import re
import time
from datetime import datetime, timedelta, timezone

import boto3
from botocore.exceptions import ClientError


REGION = os.environ["AWS_REGION_NAME"]
TARGET_ACCOUNTS = json.loads(os.environ["TARGET_ACCOUNTS"])
LOG_GROUP_PREFIXES = json.loads(os.environ["LOG_GROUP_PREFIXES"])
LOOKBACK_HOURS = int(os.environ["LOOKBACK_HOURS"])
MAX_TASKS_PER_ACCOUNT = int(os.environ["MAX_TASKS_PER_ACCOUNT"])
SNS_TOPIC_ARN = os.environ.get("SNS_TOPIC_ARN", "")

sts = boto3.client("sts")
sns = boto3.client("sns")


def _safe_prefix(value):
    clean = value.strip("/").replace("/", "-")
    return re.sub(r"[^A-Za-z0-9_.=-]", "-", clean) or "root"


def _logs_client(target):
    role_arn = target.get("role_arn", "")
    if not role_arn:
        return boto3.client("logs", region_name=REGION)

    assumed = sts.assume_role(
        RoleArn=role_arn,
        RoleSessionName=f"soc-cloudwatch-export-{target['name']}",
    )
    credentials = assumed["Credentials"]
    return boto3.client(
        "logs",
        region_name=REGION,
        aws_access_key_id=credentials["AccessKeyId"],
        aws_secret_access_key=credentials["SecretAccessKey"],
        aws_session_token=credentials["SessionToken"],
    )


def _has_active_export_task(logs):
    response = logs.describe_export_tasks(
        statusCode="RUNNING",
        limit=1,
    )
    if response.get("exportTasks"):
        return True

    response = logs.describe_export_tasks(
        statusCode="PENDING",
        limit=1,
    )
    return bool(response.get("exportTasks"))


def _iter_log_groups(logs):
    seen = set()
    paginator = logs.get_paginator("describe_log_groups")

    for prefix in LOG_GROUP_PREFIXES:
        for page in paginator.paginate(logGroupNamePrefix=prefix):
            for group in page.get("logGroups", []):
                name = group["logGroupName"]
                if name in seen:
                    continue
                seen.add(name)
                yield name


def _create_export_task(logs, target, log_group_name, from_ms, to_ms, run_key):
    group_prefix = _safe_prefix(log_group_name)
    destination_prefix = (
        f"{target['destination_prefix'].strip('/')}/{group_prefix}/{run_key}"
    )
    task_name = (
        f"fin-{target['name']}-{group_prefix}-{run_key}"
    )[:512]

    return logs.create_export_task(
        taskName=task_name,
        logGroupName=log_group_name,
        fromTime=from_ms,
        to=to_ms,
        destination=target["bucket"],
        destinationPrefix=destination_prefix,
    )


def handler(event, context):
    now = datetime.now(timezone.utc)
    start = now - timedelta(hours=LOOKBACK_HOURS)
    from_ms = int(start.timestamp() * 1000)
    to_ms = int(now.timestamp() * 1000)
    run_key = f"{start.strftime('%Y/%m/%d/%H%M')}-{now.strftime('%H%M%S')}"

    results = []

    for target in TARGET_ACCOUNTS:
        created = 0
        account_result = {
            "name": target["name"],
            "account_id": target["account_id"],
            "bucket": target["bucket"],
            "created_tasks": [],
            "skipped": [],
            "errors": [],
        }

        try:
            logs = _logs_client(target)

            if _has_active_export_task(logs):
                account_result["skipped"].append(
                    "active_export_task_exists"
                )
                results.append(account_result)
                continue

            for log_group_name in _iter_log_groups(logs):
                if created >= MAX_TASKS_PER_ACCOUNT:
                    break

                try:
                    response = _create_export_task(
                        logs,
                        target,
                        log_group_name,
                        from_ms,
                        to_ms,
                        run_key,
                    )
                    account_result["created_tasks"].append({
                        "log_group_name": log_group_name,
                        "task_id": response["taskId"],
                    })
                    created += 1
                    time.sleep(1)
                except ClientError as exc:
                    code = exc.response["Error"].get("Code", "Unknown")
                    if code in ("LimitExceededException", "ResourceAlreadyExistsException"):
                        account_result["skipped"].append(
                            f"{log_group_name}:{code}"
                        )
                        break
                    account_result["errors"].append({
                        "log_group_name": log_group_name,
                        "code": code,
                        "message": exc.response["Error"].get("Message", ""),
                    })

            if created == 0 and not account_result["skipped"]:
                account_result["skipped"].append("no_matching_log_groups")

        except ClientError as exc:
            account_result["errors"].append({
                "code": exc.response["Error"].get("Code", "Unknown"),
                "message": exc.response["Error"].get("Message", ""),
            })

        results.append(account_result)

    if SNS_TOPIC_ARN:
        created_total = sum(len(item["created_tasks"]) for item in results)
        error_total = sum(len(item["errors"]) for item in results)
        sns.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=f"SOC CloudWatch Logs export: {created_total} tasks",
            Message=json.dumps({
                "created_at": now.isoformat(),
                "lookback_hours": LOOKBACK_HOURS,
                "created_tasks": created_total,
                "errors": error_total,
                "results": results,
            }, ensure_ascii=False, indent=2),
        )

    return {
        "created_at": now.isoformat(),
        "lookback_hours": LOOKBACK_HOURS,
        "results": results,
    }
