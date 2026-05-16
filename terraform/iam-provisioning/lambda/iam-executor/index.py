"""
IAM Provisioning - IAM Executor Lambda
IAM 생성/비활성화/변경 실행
"""

import json
import os
import boto3
from datetime import datetime, timezone, timedelta
KST = timezone(timedelta(hours=9))
import secrets
import string

# 환경 변수
TARGET_ACCOUNT_IDS = json.loads(os.environ.get("TARGET_ACCOUNT_IDS", "{}"))
DYNAMODB_TABLE = os.environ.get("DYNAMODB_TABLE", "")
S3_BUCKET = os.environ.get("S3_BUCKET", "")

# AWS 클라이언트
dynamodb = boto3.resource("dynamodb")
s3_client = boto3.client("s3")
sts_client = boto3.client("sts")


def handler(event, context):
    """Step Functions에서 호출 - IAM 작업 실행"""
    print(f"Received event: {json.dumps(event)}")
    
    try:
        action = event.get("action")
        request = event.get("request", event)
        
        # ↓↓↓ 디버그 로그 추가 ↓↓↓
        print(f"Action: {action}")
        print(f"Request keys: {list(request.keys())}")
        print(f"Target accounts: {request.get('access', {}).get('target_accounts', [])}")
        print(f"Roles: {request.get('access', {}).get('roles', [])}")
        # ↑↑↑ 디버그 로그 추가 ↑↑↑
        
        if action == "onboard":
            result = execute_onboard(request)
        elif action == "offboard":
            result = execute_offboard(request)
        elif action == "modify":
            result = execute_modify(request)
        else:
            raise ValueError(f"Unknown action: {action}")
        
        # ↓↓↓ 결과 로그 추가 ↓↓↓
        print(f"Execution result: {json.dumps(result, default=str)}")
        # ↑↑↑ 결과 로그 추가 ↑↑↑
        
        # S3 파일 이동
        move_to_processed(request)
        
        return {"statusCode": 200, "result": result}
        
    except Exception as e:
        print(f"Error: {str(e)}")
        raise e


def get_iam_client(account_name):
    """대상 계정에 대한 IAM 클라이언트 반환"""
    account_id = TARGET_ACCOUNT_IDS.get(account_name)
    
    if not account_id:
        raise ValueError(f"Unknown account: {account_name}")
    
    role_arn = f"arn:aws:iam::{account_id}:role/IAMProvisioningExecutorRole"
    
    response = sts_client.assume_role(
        RoleArn=role_arn,
        RoleSessionName=f"iam-provisioning-{datetime.now(KST).strftime('%Y%m%d%H%M%S')}"
    )
    
    credentials = response["Credentials"]
    
    return boto3.client(
        "iam",
        aws_access_key_id=credentials["AccessKeyId"],
        aws_secret_access_key=credentials["SecretAccessKey"],
        aws_session_token=credentials["SessionToken"]
    )


def generate_temp_password():
    """임시 비밀번호 생성"""
    alphabet = string.ascii_letters + string.digits + "!@#$%^&*"
    return ''.join(secrets.choice(alphabet) for _ in range(16))


def execute_onboard(request):
    """입사 처리"""
    username = request["user"]["username"]
    email = request["user"]["email"]
    target_accounts = request.get("access", {}).get("target_accounts", [])
    roles = request.get("access", {}).get("roles", [])
    
    results = []
    temp_password = generate_temp_password()
    
    for account in target_accounts:
        try:
            iam_client = get_iam_client(account)
            
            # IAM User 생성
            iam_client.create_user(
                UserName=username,
                Tags=[
                    {"Key": "Email", "Value": email},
                    {"Key": "CreatedBy", "Value": "IAMProvisioning"},
                    {"Key": "CreatedAt", "Value": datetime.now(KST).isoformat()}
                ]
            )
            
            # 로그인 프로필 생성
            iam_client.create_login_profile(
                UserName=username,
                Password=temp_password,
                PasswordResetRequired=True
            )
            
            # Role/Policy 연결
            for role in roles:
                policy_arn = get_policy_arn_for_role(role, account)
                if policy_arn:
                    iam_client.attach_user_policy(UserName=username, PolicyArn=policy_arn)
            
            results.append({"account": account, "status": "SUCCESS"})
            
        except Exception as e:
            results.append({"account": account, "status": "FAILED", "message": str(e)})
    
    return {"action": "onboard", "username": username, "results": results}


def execute_offboard(request):
    """퇴사 처리"""
    username = request["user"]["username"]
    target_accounts = request.get("deactivation", {}).get("target_accounts", [])
    actions = request.get("deactivation", {}).get("actions", [])
    
    results = []
    
    for account in target_accounts:
        try:
            iam_client = get_iam_client(account)
            account_result = {"account": account, "actions": []}
            
            if "disable_console_access" in actions:
                try:
                    iam_client.delete_login_profile(UserName=username)
                    account_result["actions"].append("disable_console_access: SUCCESS")
                except:
                    pass
            
            if "deactivate_access_keys" in actions:
                keys = iam_client.list_access_keys(UserName=username)
                for key in keys.get("AccessKeyMetadata", []):
                    iam_client.update_access_key(
                        UserName=username,
                        AccessKeyId=key["AccessKeyId"],
                        Status="Inactive"
                    )
                account_result["actions"].append("deactivate_access_keys: SUCCESS")
            
            if "detach_all_policies" in actions:
                policies = iam_client.list_attached_user_policies(UserName=username)
                for policy in policies.get("AttachedPolicies", []):
                    iam_client.detach_user_policy(UserName=username, PolicyArn=policy["PolicyArn"])
                account_result["actions"].append("detach_all_policies: SUCCESS")
            
            account_result["status"] = "SUCCESS"
            results.append(account_result)
            
        except Exception as e:
            results.append({"account": account, "status": "FAILED", "message": str(e)})
    
    return {"action": "offboard", "username": username, "results": results}


def execute_modify(request):
    """권한 변경"""
    username = request["user"]["username"]
    target_accounts = request.get("changes", {}).get("target_accounts", [])
    remove = request.get("changes", {}).get("remove", {})
    add = request.get("changes", {}).get("add", {})
    
    results = []
    
    for account in target_accounts:
        try:
            iam_client = get_iam_client(account)
            account_result = {"account": account, "actions": []}
            
            # 권한 제거
            for role in remove.get("roles", []):
                policy_arn = get_policy_arn_for_role(role, account)
                if policy_arn:
                    try:
                        iam_client.detach_user_policy(UserName=username, PolicyArn=policy_arn)
                        account_result["actions"].append(f"remove {role}: SUCCESS")
                    except:
                        pass
            
            # 권한 추가
            for role in add.get("roles", []):
                policy_arn = get_policy_arn_for_role(role, account)
                if policy_arn:
                    try:
                        iam_client.attach_user_policy(UserName=username, PolicyArn=policy_arn)
                        account_result["actions"].append(f"add {role}: SUCCESS")
                    except:
                        pass
            
            account_result["status"] = "SUCCESS"
            results.append(account_result)
            
        except Exception as e:
            results.append({"account": account, "status": "FAILED", "message": str(e)})
    
    return {"action": "modify", "username": username, "results": results}


def get_policy_arn_for_role(role, account):
    """Role 이름을 Policy ARN으로 매핑"""
    aws_managed = {
        "System-Admin": "arn:aws:iam::aws:policy/AdministratorAccess",
        "Security-Audit": "arn:aws:iam::aws:policy/SecurityAudit",
        "ReadOnly": "arn:aws:iam::aws:policy/ReadOnlyAccess"
    }
    
    if role in aws_managed:
        return aws_managed[role]
    
    account_id = TARGET_ACCOUNT_IDS.get(account)
    return f"arn:aws:iam::{account_id}:policy/{role}-Policy"


def move_to_processed(request):
    """처리 완료된 파일 이동"""
    s3_key = request.get("s3_key")
    if not s3_key or not S3_BUCKET:
        return
    
    try:
        filename = s3_key.split("/")[-1]
        new_key = f"processed/{filename}"
        
        s3_client.copy_object(
            Bucket=S3_BUCKET,
            CopySource=f"{S3_BUCKET}/{s3_key}",
            Key=new_key
        )
        s3_client.delete_object(Bucket=S3_BUCKET, Key=s3_key)
    except Exception as e:
        print(f"Failed to move file: {e}")