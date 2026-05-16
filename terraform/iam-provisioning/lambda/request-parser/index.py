"""
IAM Provisioning - Request Parser Lambda
S3 YAML 파싱 → Discord 승인 요청 발송
"""

import json
import os
import boto3
import yaml
import urllib3
from datetime import datetime, timedelta, timezone
KST = timezone(timedelta(hours=9))
from botocore.exceptions import ClientError  # ← 추가

# 환경 변수
DISCORD_WEBHOOK_URL = os.environ.get("DISCORD_WEBHOOK_URL", "")
API_GATEWAY_URL = os.environ.get("API_GATEWAY_URL", "")
DYNAMODB_TABLE = os.environ.get("DYNAMODB_TABLE", "")
PENDING_TABLE = os.environ.get("PENDING_TABLE", "")
S3_BUCKET = os.environ.get("S3_BUCKET", "")
ALLOWED_ROLES = json.loads(os.environ.get("ALLOWED_ROLES", "[]"))

# AWS 클라이언트
s3_client = boto3.client("s3")
dynamodb = boto3.resource("dynamodb")
http = urllib3.PoolManager()


def handler(event, context):
    """EventBridge에서 S3 이벤트 수신 → YAML 파싱 → Discord 알림"""
    print(f"Received event: {json.dumps(event)}")
    
    try:
        bucket = event["detail"]["bucket"]["name"]
        key = event["detail"]["object"]["key"]
        
        if key.endswith("/"):
            return {"statusCode": 200, "body": "Skipped folder object"}
        
        if not key.endswith((".yaml", ".yml")):
            return {"statusCode": 200, "body": "Skipped non-YAML file"}
        
        response = s3_client.get_object(Bucket=bucket, Key=key)
        content = response["Body"].read().decode("utf-8")
        request_data = yaml.safe_load(content)
        
        print(f"Parsed request: {json.dumps(request_data, default=str)}")
        
        # 요청 유효성 검증
        validation_result = validate_request(request_data)
        if not validation_result["valid"]:
            send_validation_error(request_data, validation_result["errors"], key)
            return {"statusCode": 400, "body": validation_result["errors"]}
        
        # request_id 생성/사용
        if "request_id" not in request_data:
            request_data["request_id"] = generate_request_id()
        
        # ✅ 수정: 중복 체크하면서 저장
        save_result = save_pending_request(request_data, key)
        if not save_result["success"]:
            send_duplicate_error(request_data, key, save_result["existing_status"])
            return {
                "statusCode": 409,
                "body": json.dumps({
                    "error": "Duplicate request_id",
                    "existing_status": save_result["existing_status"]
                })
            }
        
        # Discord 승인 요청 발송
        send_approval_request(request_data, key)
        
        return {
            "statusCode": 200,
            "body": json.dumps({
                "message": "Approval request sent",
                "request_id": request_data["request_id"]
            })
        }
        
    except Exception as e:
        print(f"Error: {str(e)}")
        raise e


def validate_request(data):
    """요청 데이터 유효성 검증"""
    errors = []
    
    required_fields = ["request_type", "user", "request"]
    for field in required_fields:
        if field not in data:
            errors.append(f"필수 필드 누락: {field}")
    
    if "user" in data:
        if "username" not in data["user"]:
            errors.append("필수 필드 누락: user.username")
        if "email" not in data["user"]:
            errors.append("필수 필드 누락: user.email")
    
    request_type = data.get("request_type")
    if request_type not in ["onboard", "offboard", "modify"]:
        errors.append(f"잘못된 request_type: {request_type}")
    
    # ✅ 추가: roles 검증
    if request_type == "onboard":
        requested_roles = data.get("access", {}).get("roles", [])
        for role in requested_roles:
            if role not in ALLOWED_ROLES:
                errors.append(f"허용되지 않은 역할: {role} (허용 목록: {', '.join(ALLOWED_ROLES)})")
    
    # ✅ 추가: target_accounts 검증
    if request_type == "onboard":
        accounts = data.get("access", {}).get("target_accounts", [])
        if not accounts:
            errors.append("target_accounts가 비어있습니다")
    
    return {"valid": len(errors) == 0, "errors": errors}


def generate_request_id():
    """요청 ID 생성"""
    now = datetime.now(KST)
    return f"REQ-{now.strftime('%Y%m%d-%H%M%S')}"


def save_pending_request(data, s3_key):
    """
    DynamoDB에 pending 요청 저장 (중복 체크 포함)
    
    Returns:
        {"success": True} - 저장 성공
        {"success": False, "existing_status": "..."} - 이미 존재하는 request_id
    """
    if not PENDING_TABLE:
        return {"success": False, "existing_status": "TABLE_NOT_CONFIGURED"}
        
    table = dynamodb.Table(PENDING_TABLE)
    ttl = int((datetime.now(KST) + timedelta(days=7)).timestamp())
    
    item = {
        "request_id": data["request_id"],
        "request_type": data["request_type"],
        "username": data["user"]["username"],
        "email": data["user"]["email"],
        "s3_key": s3_key,
        "request_data": json.dumps(data, default=str),
        "status": "PENDING",
        "created_at": datetime.now(KST).isoformat(),
        "ttl": ttl
    }
    
    try:
        # ✅ 핵심: ConditionExpression으로 중복 방지
        table.put_item(
            Item=item,
            ConditionExpression="attribute_not_exists(request_id)"
        )
        return {"success": True}
        
    except ClientError as e:
        if e.response["Error"]["Code"] == "ConditionalCheckFailedException":
            # 이미 존재하는 request_id → 현재 상태 조회
            existing = table.get_item(Key={"request_id": data["request_id"]})
            existing_status = existing.get("Item", {}).get("status", "UNKNOWN")
            
            print(f"Duplicate request_id: {data['request_id']} (existing status: {existing_status})")
            return {"success": False, "existing_status": existing_status}
        else:
            raise


def send_duplicate_error(data, s3_key, existing_status):
    """중복 요청 알림"""
    if not DISCORD_WEBHOOK_URL:
        return
        
    request_id = data.get("request_id", "Unknown")
    username = data.get("user", {}).get("username", "Unknown")
    
    message = {
        "embeds": [{
            "title": "🚫 중복 요청 거부",
            "color": 0xFF6600,
            "description": "동일한 request_id로 이미 처리된 요청이 있습니다.",
            "fields": [
                {"name": "📋 요청 ID", "value": f"`{request_id}`", "inline": True},
                {"name": "📌 기존 상태", "value": existing_status, "inline": True},
                {"name": "👤 사용자", "value": username, "inline": True},
                {"name": "📁 파일", "value": s3_key, "inline": False},
                {"name": "💡 안내", "value": "새로운 request_id로 다시 요청해주세요.", "inline": False}
            ]
        }]
    }
    
    http.request(
        "POST",
        DISCORD_WEBHOOK_URL,
        body=json.dumps(message),
        headers={"Content-Type": "application/json"}
    )


def send_approval_request(data, s3_key):
    """Discord 승인 요청 알림 발송"""
    if not DISCORD_WEBHOOK_URL:
        print("Discord webhook URL not configured")
        return
        
    request_type = data["request_type"]
    username = data["user"]["username"]
    email = data["user"]["email"]
    request_id = data["request_id"]
    requester = data.get("request", {}).get("requester", "Unknown")
    
    type_config = {
        "onboard": {"emoji": "🟢", "title": "입사자 IAM 생성 요청", "color": 0x00FF00},
        "offboard": {"emoji": "🔴", "title": "퇴사자 IAM 비활성화 요청", "color": 0xFF0000},
        "modify": {"emoji": "🟡", "title": "권한 변경 요청", "color": 0xFFFF00}
    }
    
    config = type_config.get(request_type, {"emoji": "📋", "title": "IAM 요청", "color": 0x808080})
    
    approve_url = f"{API_GATEWAY_URL}/approve?request_id={request_id}&approver=admin"
    deny_url = f"{API_GATEWAY_URL}/deny?request_id={request_id}&approver=admin"
    
    extra_info = ""
    if request_type == "onboard":
        accounts = data.get("access", {}).get("target_accounts", [])
        roles = data.get("access", {}).get("roles", [])
        extra_info = f"\n**계정:** {', '.join(accounts)}\n**역할:** {', '.join(roles)}"
    elif request_type == "offboard":
        accounts = data.get("deactivation", {}).get("target_accounts", [])
        extra_info = f"\n**계정:** {', '.join(accounts)}"
    elif request_type == "modify":
        accounts = data.get("changes", {}).get("target_accounts", [])
        reason = data.get("request", {}).get("reason", "N/A")
        extra_info = f"\n**계정:** {', '.join(accounts)}\n**사유:** {reason}"
    
    message = {
        "content": (
            f"# {config['emoji']} {config['title']}\n\n"
            f"**📋 요청 ID:** `{request_id}`\n"
            f"**👤 사용자:** {username}\n"
            f"**📧 이메일:** {email}\n"
            f"**🙋 요청자:** {requester}\n"
            f"**📅 요청 시간:** {datetime.now(KST).strftime('%Y-%m-%d %H:%M:%S KST')}"
            f"{extra_info}\n\n"
            f"━━━━━━━━━━━━━━━━━━━━━━━━━\n"
            f"### 🔗 승인/거부 링크\n"
            f"### ✅ **[승인하기]({approve_url})**\n"
            f"### ❌ **[거부하기]({deny_url})**\n"
            f"━━━━━━━━━━━━━━━━━━━━━━━━━"
        )
    }
    
    response = http.request(
        "POST",
        DISCORD_WEBHOOK_URL,
        body=json.dumps(message),
        headers={"Content-Type": "application/json"}
    )
    
    print(f"Discord notification sent: {response.status}")


def send_validation_error(data, errors, s3_key):
    """검증 실패 알림 발송"""
    if not DISCORD_WEBHOOK_URL:
        return
        
    username = data.get("user", {}).get("username", "Unknown")
    
    message = {
        "embeds": [{
            "title": "⚠️ 요청 검증 실패",
            "color": 0xFF6600,
            "fields": [
                {"name": "👤 사용자", "value": username, "inline": True},
                {"name": "📁 파일", "value": s3_key, "inline": True},
                {"name": "❌ 오류 목록", "value": "\n".join([f"• {e}" for e in errors]), "inline": False}
            ]
        }]
    }
    
    http.request(
        "POST",
        DISCORD_WEBHOOK_URL,
        body=json.dumps(message),
        headers={"Content-Type": "application/json"}
    )