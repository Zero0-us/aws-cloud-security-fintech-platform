import csv
import io
import json
import os
import time
from datetime import datetime, timezone

import boto3


athena = boto3.client("athena")
config = boto3.client("config")
s3 = boto3.client("s3")
sns = boto3.client("sns")


COMPLIANCE_BUCKET = os.environ["COMPLIANCE_BUCKET"]
ATHENA_DATABASE = os.environ["ATHENA_DATABASE"]
ATHENA_WORKGROUP = os.environ["ATHENA_WORKGROUP"]
ATHENA_RESULTS_BUCKET = os.environ["ATHENA_RESULTS_BUCKET"]
SNS_TOPIC_ARN = os.environ["SNS_TOPIC_ARN"]
CONTROL_MAPPING_KEY = os.environ["CONTROL_MAPPING_KEY"]
LOG_INTAKE_MANIFEST_KEY = os.environ["LOG_INTAKE_MANIFEST_KEY"]
CONFIG_RULES = [item for item in os.environ["CONFIG_RULE_NAMES"].split(",") if item]


def _load_json_from_s3(key):
    response = s3.get_object(Bucket=COMPLIANCE_BUCKET, Key=key)
    return json.loads(response["Body"].read().decode("utf-8"))


def _collect_config_compliance():
    rows = []
    for rule_name in CONFIG_RULES:
        result = config.describe_compliance_by_config_rule(
            ConfigRuleNames=[rule_name]
        )["ComplianceByConfigRules"]
        if not result:
            rows.append({
                "rule_name": rule_name,
                "compliance_type": "NOT_EVALUATED",
                "compliant_count": 0,
                "non_compliant_count": 0,
            })
            continue

        compliance = result[0].get("Compliance", {})
        summary = compliance.get("ComplianceContributorCount", {})
        rows.append({
            "rule_name": rule_name,
            "compliance_type": compliance.get("ComplianceType", "UNKNOWN"),
            "compliant_count": summary.get("CappedCount", 0)
            if compliance.get("ComplianceType") == "COMPLIANT"
            else 0,
            "non_compliant_count": summary.get("CappedCount", 0)
            if compliance.get("ComplianceType") == "NON_COMPLIANT"
            else 0,
        })
    return rows


def _run_athena_summary():
    query = """
    SELECT recipientaccountid, eventsource, eventname, COUNT(*) AS event_count
    FROM cloudtrail_logs
    WHERE eventtime >= date_format(date_add('month', -1, current_date), '%Y-%m-%d')
    GROUP BY recipientaccountid, eventsource, eventname
    ORDER BY event_count DESC
    LIMIT 200
    """
    response = athena.start_query_execution(
        QueryString=query,
        QueryExecutionContext={"Database": ATHENA_DATABASE},
        WorkGroup=ATHENA_WORKGROUP,
        ResultConfiguration={
            "OutputLocation": f"s3://{ATHENA_RESULTS_BUCKET}/athena-results/monthly-audit/"
        },
    )
    execution_id = response["QueryExecutionId"]

    for _ in range(60):
        status = athena.get_query_execution(QueryExecutionId=execution_id)
        state = status["QueryExecution"]["Status"]["State"]
        if state in ("SUCCEEDED", "FAILED", "CANCELLED"):
            break
        time.sleep(5)

    if state != "SUCCEEDED":
        reason = status["QueryExecution"]["Status"].get("StateChangeReason", "")
        return execution_id, [{"status": state, "reason": reason}]

    rows = []
    paginator = athena.get_paginator("get_query_results")
    for page in paginator.paginate(QueryExecutionId=execution_id):
        for row in page["ResultSet"]["Rows"][1:]:
            values = [col.get("VarCharValue", "") for col in row["Data"]]
            rows.append({
                "recipient_account_id": values[0],
                "event_source": values[1],
                "event_name": values[2],
                "event_count": values[3],
            })
    return execution_id, rows


def _to_csv(rows, fieldnames):
    output = io.StringIO()
    writer = csv.DictWriter(output, fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(rows)
    return output.getvalue()


def handler(event, context):
    generated_at = datetime.now(timezone.utc)
    month_key = generated_at.strftime("%Y-%m")
    base_key = f"monthly-audit/{month_key}/soc-audit-report-{generated_at.strftime('%Y%m%dT%H%M%SZ')}"

    control_mapping = _load_json_from_s3(CONTROL_MAPPING_KEY)
    log_manifest = _load_json_from_s3(LOG_INTAKE_MANIFEST_KEY)
    config_rows = _collect_config_compliance()
    athena_execution_id, cloudtrail_rows = _run_athena_summary()

    non_compliant = [
        row for row in config_rows if row["compliance_type"] == "NON_COMPLIANT"
    ]
    report = {
        "generated_at": generated_at.isoformat(),
        "period": "previous_month_to_now",
        "summary": {
            "config_rules_checked": len(config_rows),
            "non_compliant_rules": len(non_compliant),
            "cloudtrail_summary_rows": len(cloudtrail_rows),
            "athena_execution_id": athena_execution_id,
        },
        "isms_p_control_mapping": control_mapping,
        "service_log_intake_manifest": log_manifest,
        "config_compliance": config_rows,
        "cloudtrail_activity_summary": cloudtrail_rows,
    }

    json_key = f"{base_key}.json"
    csv_key = f"{base_key}-config-compliance.csv"
    s3.put_object(
        Bucket=COMPLIANCE_BUCKET,
        Key=json_key,
        Body=json.dumps(report, ensure_ascii=False, indent=2).encode("utf-8"),
        ContentType="application/json",
    )
    s3.put_object(
        Bucket=COMPLIANCE_BUCKET,
        Key=csv_key,
        Body=_to_csv(
            config_rows,
            ["rule_name", "compliance_type", "compliant_count", "non_compliant_count"],
        ).encode("utf-8"),
        ContentType="text/csv",
    )

    message = "\n".join([
        "Monthly SOC audit report generated.",
        f"JSON: s3://{COMPLIANCE_BUCKET}/{json_key}",
        f"CSV: s3://{COMPLIANCE_BUCKET}/{csv_key}",
        f"Config rules checked: {len(config_rows)}",
        f"Non-compliant rules: {len(non_compliant)}",
        f"Athena execution ID: {athena_execution_id}",
    ])
    sns.publish(
        TopicArn=SNS_TOPIC_ARN,
        Subject=f"Monthly SOC audit report - {month_key}",
        Message=message,
    )

    return {
        "report": f"s3://{COMPLIANCE_BUCKET}/{json_key}",
        "config_csv": f"s3://{COMPLIANCE_BUCKET}/{csv_key}",
        "non_compliant_rules": len(non_compliant),
    }
