"""
IAM Provisioning - Approval Handler Lambda
API Gateway에서 승인/거부 요청 처리
"""

import json
import os
import boto3
import urllib3
from botocore.exceptions import ClientError
from datetime import datetime, timezone, timedelta
KST = timezone(timedelta(hours=9))


# 환경 변수
DYNAMODB_TABLE = os.environ.get("DYNAMODB_TABLE", "")
PENDING_TABLE = os.environ.get("PENDING_TABLE", "")
STATE_MACHINE_ARN = os.environ.get("STATE_MACHINE_ARN", "")
DISCORD_WEBHOOK_URL = os.environ.get("DISCORD_WEBHOOK_URL", "")
S3_BUCKET = os.environ.get("S3_BUCKET", "")

# AWS 클라이언트
dynamodb = boto3.resource("dynamodb")
sfn_client = boto3.client("stepfunctions")
s3_client = boto3.client("s3")
http = urllib3.PoolManager()

# 봇 차단 키워드 (Discord 미리보기 fetch 차단)
BOT_KEYWORDS = [
    "discordbot", "slackbot", "telegrambot",
    "facebookexternalhit", "twitterbot", "linkedinbot",
    "whatsapp", "preview", "crawler", "spider",
]


def handler(event, context):
    """API Gateway에서 승인/거부 요청 처리"""
    print(f"Received event: {json.dumps(event)}")
    
    try:
        # ✅ 1. 봇 차단
        headers = event.get("headers", {})
        user_agent = headers.get("user-agent", "").lower()
        
        if any(keyword in user_agent for keyword in BOT_KEYWORDS):
            print(f"⚠️ Blocked bot request: {user_agent}")
            return {
                "statusCode": 200,
                "headers": {"Content-Type": "text/html; charset=utf-8"},
                "body": "<html><body><h1>Action Link</h1><p>Please open this link in a browser.</p></body></html>"
            }
        
        path = event.get("rawPath", "")
        method = event.get("requestContext", {}).get("http", {}).get("method", "GET")
        query_params = event.get("queryStringParameters", {}) or {}
        
        request_id = query_params.get("request_id")
        approver = query_params.get("approver", "Admin")
        
        if not request_id:
            return error_response(400, "request_id is required")
        
        # ✅ 2. GET 요청은 확인 페이지로
        if method == "GET" and ("/approve" in path or "/deny" in path):
            return show_confirmation_page(event, path, request_id, approver)
        
        # ✅ 3. POST 요청만 실제 처리
        if "/status" in path:
            return get_request_status(request_id)
        elif "/approve" in path:
            return process_approval(request_id, approver)
        elif "/deny" in path:
            reason = query_params.get("reason", "승인자 검토 결과 부적합")
            return process_denial(request_id, approver, reason)
        
        return error_response(404, "Unknown endpoint")
        
    except Exception as e:
        print(f"Error: {str(e)}")
        return error_response(500, str(e))


def process_approval(request_id, approver):
    """승인 처리 (Race Condition 방지)"""
    if not PENDING_TABLE:
        return error_response(500, "PENDING_TABLE not configured")
        
    table = dynamodb.Table(PENDING_TABLE)
    
    # ✅ 핵심: ConditionExpression으로 PENDING일 때만 업데이트
    # Race Condition 발생해도 DynamoDB가 원자적으로 처리
    try:
        response = table.update_item(
            Key={"request_id": request_id},
            UpdateExpression="SET #status = :new_status, approver = :approver, approved_at = :approved_at",
            ConditionExpression="#status = :pending_status",
            ExpressionAttributeNames={"#status": "status"},
            ExpressionAttributeValues={
                ":new_status": "APPROVED",
                ":pending_status": "PENDING",
                ":approver": approver,
                ":approved_at": datetime.now(KST).isoformat()
            },
            ReturnValues="ALL_NEW"
        )
        item = response["Attributes"]
        
    except ClientError as e:
        if e.response["Error"]["Code"] == "ConditionalCheckFailedException":
            # 이미 처리된 요청 (PENDING이 아님)
            existing = table.get_item(Key={"request_id": request_id})
            if "Item" not in existing:
                return error_response(404, "Request not found")
            current_status = existing["Item"].get("status", "UNKNOWN")
            print(f"⚠️ Already processed: {request_id} (status: {current_status})")
            return error_response(409, f"Request already {current_status}")
        raise
    
    # 여기 도달 = PENDING이었던 게 정상적으로 APPROVED로 변경됨
    request_data = json.loads(item["request_data"])
    request_data["approver"] = approver
    request_data["approved_at"] = datetime.now(KST).isoformat()
    request_data["s3_key"] = item.get("s3_key", "")
    
    # Step Functions 실행 (IAM 생성 시작)
    if STATE_MACHINE_ARN:
        execution_name = f"{request_id}-{datetime.now(KST).strftime('%Y%m%d%H%M%S')}"
        sfn_response = sfn_client.start_execution(
            stateMachineArn=STATE_MACHINE_ARN,
            name=execution_name,
            input=json.dumps(request_data, default=str)
        )
        print(f"Started execution: {sfn_response['executionArn']}")
    
    # Discord 알림
    send_approval_notification(request_data, approver)
    
    return success_response({
        "message": "Request approved",
        "request_id": request_id
    })


def process_denial(request_id, approver, reason):
    """거부 처리 (Race Condition 방지)"""
    if not PENDING_TABLE:
        return error_response(500, "PENDING_TABLE not configured")
        
    table = dynamodb.Table(PENDING_TABLE)
    
    # ✅ 핵심: ConditionExpression
    try:
        response = table.update_item(
            Key={"request_id": request_id},
            UpdateExpression="SET #status = :new_status, approver = :approver, denied_at = :denied_at, denial_reason = :reason",
            ConditionExpression="#status = :pending_status",
            ExpressionAttributeNames={"#status": "status"},
            ExpressionAttributeValues={
                ":new_status": "REJECTED",
                ":pending_status": "PENDING",
                ":approver": approver,
                ":denied_at": datetime.now(KST).isoformat(),
                ":reason": reason
            },
            ReturnValues="ALL_NEW"
        )
        item = response["Attributes"]
        
    except ClientError as e:
        if e.response["Error"]["Code"] == "ConditionalCheckFailedException":
            existing = table.get_item(Key={"request_id": request_id})
            if "Item" not in existing:
                return error_response(404, "Request not found")
            current_status = existing["Item"].get("status", "UNKNOWN")
            print(f"⚠️ Already processed: {request_id} (status: {current_status})")
            return error_response(409, f"Request already {current_status}")
        raise
    
    # 여기 도달 = PENDING → REJECTED 정상 변경됨
    request_data = json.loads(item["request_data"])
    
    # Discord 알림
    send_denial_notification(request_data, approver, reason)
    
    return success_response({
        "message": "Request denied",
        "request_id": request_id
    })
    
def show_confirmation_page(event, path, request_id, approver):
    """GET 요청 시 확인 페이지 반환 (실제 처리는 POST)"""
    
    if "/approve" in path:
        action = "승인"
        action_endpoint = "approve"
        button_color = "#28a745"
        emoji = "✅"
        is_deny = False
    elif "/deny" in path:
        action = "거부"
        action_endpoint = "deny"
        button_color = "#dc3545"
        emoji = "❌"
        is_deny = True
    else:
        return error_response(404, "Unknown")
    
    host = event.get("headers", {}).get("host", "")
    stage = event.get("requestContext", {}).get("stage", "prod")
    api_url = f"https://{host}/{stage}/{action_endpoint}"
    
    # 거부 시에만 사유 입력 폼
    reason_form = ""
    if is_deny:
        reason_form = """
        <div class="reason-section">
            <label for="reasonInput"><strong>거부 사유 (선택)</strong></label>
            <textarea id="reasonInput" rows="3" placeholder="거부 사유를 입력하세요. (미입력 시 기본 사유 적용)"></textarea>
            <small>비워두면 '승인자 검토 결과 부적합'으로 자동 기록됩니다.</small>
        </div>
        """
    
    html = f"""<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>IAM 요청 {action}</title>
    <style>
        body {{ font-family: -apple-system, sans-serif; background: #f5f5f5; display: flex; align-items: center; justify-content: center; min-height: 100vh; margin: 0; padding: 20px; }}
        .card {{ background: white; border-radius: 12px; box-shadow: 0 4px 20px rgba(0,0,0,0.1); padding: 40px; max-width: 480px; width: 100%; text-align: center; }}
        h1 {{ margin: 0 0 20px; color: #333; }}
        .info {{ background: #f8f9fa; padding: 20px; border-radius: 8px; margin: 20px 0; text-align: left; }}
        .info-row {{ margin: 10px 0; color: #555; }}
        .info-label {{ font-weight: bold; color: #333; display: inline-block; width: 100px; }}
        .reason-section {{ margin: 20px 0; text-align: left; }}
        .reason-section label {{ display: block; margin-bottom: 8px; color: #333; }}
        .reason-section textarea {{ width: 100%; padding: 10px; border: 1px solid #ddd; border-radius: 6px; font-family: inherit; font-size: 14px; resize: vertical; box-sizing: border-box; }}
        .reason-section textarea:focus {{ outline: none; border-color: #dc3545; }}
        .reason-section small {{ display: block; margin-top: 6px; color: #888; font-size: 12px; }}
        button {{ background: {button_color}; color: white; padding: 14px 40px; border: none; border-radius: 8px; font-size: 16px; font-weight: 600; cursor: pointer; margin-top: 10px; }}
        button:hover {{ opacity: 0.9; }}
        button:disabled {{ background: #999; cursor: not-allowed; }}
        .warning {{ background: #fff3cd; color: #856404; padding: 12px; border-radius: 6px; margin: 20px 0; font-size: 14px; }}
        #result {{ margin-top: 20px; padding: 15px; border-radius: 8px; display: none; }}
        .success {{ background: #d4edda; color: #155724; }}
        .error {{ background: #f8d7da; color: #721c24; }}
    </style>
</head>
<body>
    <div class="card">
        <h1>{emoji} IAM 요청 {action}</h1>
        <div class="info">
            <div class="info-row"><span class="info-label">요청 ID:</span> {request_id}</div>
            <div class="info-row"><span class="info-label">작업:</span> {action}</div>
            <div class="info-row"><span class="info-label">승인자:</span> {approver}</div>
        </div>
        {reason_form}
        <p style="color:#666;">아래 버튼을 클릭하여 {action}을(를) 확정하세요.</p>
        <button id="confirmBtn" onclick="confirmAction()">{action} 확정</button>
        <div class="warning">⚠️ 이 작업은 되돌릴 수 없습니다.</div>
        <div id="result"></div>
    </div>
    <script>
        const REQUEST_ID = "{request_id}";
        const APPROVER = "{approver}";
        const API_BASE = "{api_url}";
        const IS_DENY = {str(is_deny).lower()};
        
        async function confirmAction() {{
            const btn = document.getElementById('confirmBtn');
            const result = document.getElementById('result');
            btn.disabled = true;
            btn.innerText = '처리 중...';
            
            // URL 파라미터 구성
            let url = API_BASE + '?request_id=' + encodeURIComponent(REQUEST_ID) + '&approver=' + encodeURIComponent(APPROVER);
            
            // 거부 시 사유 추가
            if (IS_DENY) {{
                const reasonEl = document.getElementById('reasonInput');
                let reason = reasonEl ? reasonEl.value.trim() : '';
                if (!reason) {{
                    reason = '승인자 검토 결과 부적합';
                }}
                url += '&reason=' + encodeURIComponent(reason);
            }}
            
            try {{
                const response = await fetch(url, {{ method: 'POST' }});
                const data = await response.json();
                result.style.display = 'block';
                if (response.ok) {{
                    result.className = 'success';
                    result.innerHTML = '<strong>{action} 완료!</strong><br>' + (data.message || '');
                    btn.innerText = '완료됨';
                }} else {{
                    result.className = 'error';
                    result.innerHTML = '<strong>실패</strong><br>' + (data.error || 'Unknown error');
                    btn.disabled = false;
                    btn.innerText = '{action} 확정';
                }}
            }} catch (e) {{
                result.style.display = 'block';
                result.className = 'error';
                result.innerHTML = '<strong>오류</strong><br>' + e.message;
                btn.disabled = false;
                btn.innerText = '{action} 확정';
            }}
        }}
    </script>
</body>
</html>"""
    
    return {
        "statusCode": 200,
        "headers": {"Content-Type": "text/html; charset=utf-8"},
        "body": html
    }



def send_approval_notification(data, approver):
    """승인 알림 발송"""
    if not DISCORD_WEBHOOK_URL:
        return
        
    message = {
        "embeds": [{
            "title": "✅ 요청 승인됨",
            "color": 0x00FF00,
            "fields": [
                {"name": "📋 요청 ID", "value": f"`{data['request_id']}`", "inline": True},
                {"name": "👤 사용자", "value": data["user"]["username"], "inline": True},
                {"name": "✍️ 승인자", "value": approver, "inline": True}
            ]
        }]
    }
    
    http.request(
        "POST",
        DISCORD_WEBHOOK_URL,
        body=json.dumps(message),
        headers={"Content-Type": "application/json"}
    )


def send_denial_notification(data, approver, reason):
    """거부 알림 발송"""
    if not DISCORD_WEBHOOK_URL:
        return
        
    message = {
        "embeds": [{
            "title": "❌ 요청 거부됨",
            "color": 0xFF0000,
            "fields": [
                {"name": "📋 요청 ID", "value": f"`{data['request_id']}`", "inline": True},
                {"name": "👤 사용자", "value": data["user"]["username"], "inline": True},
                {"name": "✍️ 거부자", "value": approver, "inline": True},
                {"name": "📝 사유", "value": reason, "inline": False}
            ]
        }]
    }
    
    http.request(
        "POST",
        DISCORD_WEBHOOK_URL,
        body=json.dumps(message),
        headers={"Content-Type": "application/json"}
    )


def success_response(body):
    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*"
        },
        "body": json.dumps(body)
    }


def error_response(status_code, message):
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*"
        },
        "body": json.dumps({"error": message})
    }
        