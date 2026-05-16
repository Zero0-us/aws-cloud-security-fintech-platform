"""
IAM Provisioning - Discord Notifier Lambda
완료/실패 알림 발송
"""

import json
import os
import urllib3
from datetime import datetime, timezone, timedelta

KST = timezone(timedelta(hours=9))

DISCORD_WEBHOOK_URL = os.environ.get("DISCORD_WEBHOOK_URL", "")
http = urllib3.PoolManager()


def handler(event, context):
    """Step Functions에서 호출 - Discord 알림 발송"""
    print(f"Received event: {json.dumps(event)}")
    
    try:
        status = event.get("status")
        request = event.get("request", {})
        error = event.get("error")
        
        if status == "success":
            send_success_notification(request)
        elif status == "failure":
            send_failure_notification(request, error)
        
        return {"statusCode": 200}
        
    except Exception as e:
        print(f"Error: {str(e)}")
        raise e


def send_success_notification(request):
    """성공 알림 발송"""
    if not DISCORD_WEBHOOK_URL:
        return
        
    request_type = request.get("request_type", "unknown")
    request_id = request.get("request_id", "N/A")
    username = request.get("user", {}).get("username", "Unknown")
    approver = request.get("approver", "N/A")
    
    type_config = {
        "onboard": {"emoji": "🟢", "title": "입사자 IAM 생성 완료"},
        "offboard": {"emoji": "🔴", "title": "퇴사자 IAM 비활성화 완료"},
        "modify": {"emoji": "🟡", "title": "권한 변경 완료"}
    }
    
    config = type_config.get(request_type, {"emoji": "✅", "title": "작업 완료"})
    
    message = {
        "embeds": [{
            "title": f"{config['emoji']} {config['title']}",
            "color": 0x00FF00,
            "fields": [
                {"name": "📋 요청 ID", "value": f"`{request_id}`", "inline": True},
                {"name": "👤 사용자", "value": username, "inline": True},
                {"name": "✍️ 승인자", "value": approver, "inline": True},
                {"name": "📅 완료 시간", "value": datetime.now(KST).strftime("%Y-%m-%d %H:%M:%S KST"), "inline": True}
            ]
        }]
    }
    
    http.request(
        "POST",
        DISCORD_WEBHOOK_URL,
        body=json.dumps(message),
        headers={"Content-Type": "application/json"}
    )


def send_failure_notification(request, error):
    """실패 알림 발송"""
    if not DISCORD_WEBHOOK_URL:
        return
        
    request_id = request.get("request_id", "N/A")
    username = request.get("user", {}).get("username", "Unknown")
    
    error_message = str(error) if error else "Unknown error"
    
    message = {
        "embeds": [{
            "title": "❌ 작업 실패",
            "color": 0xFF0000,
            "fields": [
                {"name": "📋 요청 ID", "value": f"`{request_id}`", "inline": True},
                {"name": "👤 사용자", "value": username, "inline": True},
                {"name": "❌ 에러", "value": f"```{error_message[:500]}```", "inline": False}
            ]
        }]
    }
    
    http.request(
        "POST",
        DISCORD_WEBHOOK_URL,
        body=json.dumps(message),
        headers={"Content-Type": "application/json"}
    )