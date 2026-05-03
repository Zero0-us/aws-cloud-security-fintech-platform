from fastapi import FastAPI, HTTPException, Request
from pydantic import BaseModel, validator
from datetime import datetime, timedelta
import hashlib, hmac, uuid, json, re, random
import asyncpg, redis.asyncio as redis
import bcrypt, pyotp, jwt, base64, os

app = FastAPI(title="Auth Service", version="2.0")

DB_URL = os.getenv("DATABASE_URL", "postgresql://fintech:FintechDB2026!Secure@postgres:5432/fintech_db")
REDIS_URL = os.getenv("REDIS_URL", "redis://:RedisPass2026!Secure@redis:6379")
JWT_SECRET = os.getenv("JWT_SECRET_KEY", "fintech-jwt-secret-2026")

db_pool = None
redis_client = None

@app.on_event("startup")
async def startup():
    global db_pool, redis_client
    db_pool = await asyncpg.create_pool(DB_URL, min_size=2, max_size=10)
    redis_client = redis.from_url(REDIS_URL, decode_responses=True)

@app.get("/health")
async def health():
    return {"status": "healthy", "service": "auth-service", "timestamp": datetime.now().isoformat()}

# ============ Models ============

class LoginRequest(BaseModel):
    username: str
    password: str
    otp_code: str

class RegisterRequest(BaseModel):
    username: str
    password: str
    full_name: str
    phone: str = ""

    @validator('password')
    def validate_password(cls, v):
        if len(v) < 8:
            raise ValueError('비밀번호는 8자 이상이어야 합니다')
        if not re.search(r'[A-Z]', v):
            raise ValueError('대문자를 포함해야 합니다')
        if not re.search(r'[a-z]', v):
            raise ValueError('소문자를 포함해야 합니다')
        if not re.search(r'[0-9]', v):
            raise ValueError('숫자를 포함해야 합니다')
        if not re.search(r'[!@#$%^&*]', v):
            raise ValueError('특수문자(!@#$%^&*)를 포함해야 합니다')
        return v

    @validator('username')
    def validate_username(cls, v):
        if len(v) < 4:
            raise ValueError('아이디는 4자 이상이어야 합니다')
        if not re.match(r'^[a-zA-Z0-9_]+$', v):
            raise ValueError('아이디는 영문, 숫자, _만 사용 가능합니다')
        return v

class AdminUserUpdate(BaseModel):
    action: str
    role: str = ""
    username: str = ""
    full_name: str = ""
    phone: str = ""

# ============ Login ============

@app.post("/api/v1/auth/login")
async def login(req: LoginRequest, request: Request):
    ip = request.headers.get("X-Real-IP", request.client.host)

    fail_key = f"login_fail:{req.username}"
    fails = await redis_client.get(fail_key)
    if fails and int(fails) >= 5:
        await log_audit(None, "ACCOUNT_LOCKED", ip, "high", {"message": f"계정 잠금 (5회 실패): {req.username}"})
        raise HTTPException(status_code=423, detail="계정이 잠겨있습니다. 5분 후 재시도하세요.")

    async with db_pool.acquire() as conn:
        user = await conn.fetchrow("SELECT * FROM users WHERE username=$1", req.username)

    if not user:
        await redis_client.incr(fail_key)
        await redis_client.expire(fail_key, 300)
        await log_audit(None, "LOGIN_FAILED", ip, "high", {"message": f"존재하지 않는 사용자: {req.username}"})
        raise HTTPException(status_code=401, detail="아이디 또는 비밀번호가 올바르지 않습니다")

    if user.get("is_locked", False):
        raise HTTPException(status_code=423, detail="관리자에 의해 잠긴 계정입니다.")

    if not bcrypt.checkpw(req.password.encode(), user["hashed_password"].encode()):
        await redis_client.incr(fail_key)
        await redis_client.expire(fail_key, 300)
        await log_audit(str(user["id"]), "LOGIN_FAILED", ip, "high", {"message": "비밀번호 불일치"})
        raise HTTPException(status_code=401, detail="아이디 또는 비밀번호가 올바르지 않습니다")

    totp = pyotp.TOTP(user["totp_secret"])
    if not totp.verify(req.otp_code, valid_window=1):
        await log_audit(str(user["id"]), "MFA_FAILED", ip, "high", {"message": "OTP 인증 실패"})
        raise HTTPException(status_code=401, detail="인증코드가 올바르지 않습니다")

    await redis_client.delete(fail_key)

    now = datetime.utcnow()
    jti = str(uuid.uuid4())
    roles = list(user["roles"]) if user["roles"] else ["user"]

    token = jwt.encode({
        "sub": str(user["id"]), "username": user["username"],
        "full_name": user.get("full_name", user["username"]),
        "roles": roles,
        "iat": now, "exp": now + timedelta(minutes=15),
        "jti": jti, "iss": "fintech-auth"
    }, JWT_SECRET, algorithm="HS256")

    await redis_client.setex(f"session:{jti}", 900, str(user["id"]))

    async with db_pool.acquire() as conn:
        await conn.execute("UPDATE users SET last_login=$1 WHERE id=$2", now, user["id"])

    await log_audit(str(user["id"]), "LOGIN_SUCCESS", ip, "low", {"message": f"MFA 인증 완료, JWT 발급: {jti[:8]}..."})

    return {
        "access_token": token, "token_type": "Bearer", "expires_in": 900,
        "user_id": str(user["id"]),
        "username": user["username"],
        "full_name": user.get("full_name", user["username"]),
        "roles": roles
    }

# ============ Register ============

@app.post("/api/v1/auth/register")
async def register(req: RegisterRequest, request: Request):
    ip = request.headers.get("X-Real-IP", request.client.host)

    async with db_pool.acquire() as conn:
        existing = await conn.fetchrow("SELECT id FROM users WHERE username=$1", req.username)
        if existing:
            raise HTTPException(status_code=409, detail="이미 사용 중인 아이디입니다")

        user_id = str(uuid.uuid4())
        hashed_pw = bcrypt.hashpw(req.password.encode(), bcrypt.gensalt(12)).decode()
        totp_secret = pyotp.random_base32()

        await conn.execute("""
            INSERT INTO users (id, username, hashed_password, full_name, phone, totp_secret, roles, is_locked, created_at)
            VALUES ($1, $2, $3, $4, $5, $6, $7, false, $8)
        """, uuid.UUID(user_id), req.username, hashed_pw, req.full_name, req.phone,
            totp_secret, ["user"], datetime.utcnow())

        acc_id = str(uuid.uuid4())
        acc_num = f"{random.randint(1000,9999)}-{random.randint(1000,9999)}-{random.randint(1000,9999)}-{random.randint(1000,9999)}"
        await conn.execute("""
            INSERT INTO accounts (id, user_id, account_number_encrypted, account_type, balance, currency, created_at)
            VALUES ($1, $2, $3, 'checking', 1000000, 'KRW', $4)
        """, uuid.UUID(acc_id), uuid.UUID(user_id), acc_num, datetime.utcnow())

    totp_uri = pyotp.TOTP(totp_secret).provisioning_uri(name=req.username, issuer_name="SecureBank")

    await log_audit(user_id, "USER_REGISTERED", ip, "low", {"message": f"신규 회원가입: {req.username}"})

    return {
        "status": "success",
        "user_id": user_id,
        "username": req.username,
        "totp_secret": totp_secret,
        "totp_uri": totp_uri,
        "message": "회원가입 완료. TOTP 앱에 아래 키를 등록하세요.",
        "initial_balance": 1000000,
        "account_number": acc_num
    }

# ============ Admin: User Management ============

@app.get("/api/v1/auth/users")
async def list_users():
    async with db_pool.acquire() as conn:
        rows = await conn.fetch("""
            SELECT u.id, u.username, u.full_name, u.phone, u.roles, u.is_locked, u.created_at, u.last_login,
                   (SELECT COUNT(*) FROM accounts a WHERE a.user_id = u.id) as account_count,
                   (SELECT COALESCE(SUM(a.balance),0) FROM accounts a WHERE a.user_id = u.id) as total_balance
            FROM users u ORDER BY u.created_at DESC
        """)

    users = []
    for r in rows:
        roles = list(r["roles"]) if r["roles"] else ["user"]
        users.append({
            "user_id": str(r["id"]),
            "username": r["username"],
            "full_name": r.get("full_name", r["username"]),
            "phone": r.get("phone", "") or "",
            "roles": roles,
            "is_locked": r.get("is_locked", False),
            "account_count": r["account_count"],
            "total_balance": float(r["total_balance"]),
            "created_at": r["created_at"].isoformat() if r["created_at"] else None,
            "last_login": r["last_login"].isoformat() if r.get("last_login") else None
        })

    return {"users": users, "total": len(users)}

@app.put("/api/v1/auth/users/{user_id}")
async def update_user(user_id: str, req: AdminUserUpdate, request: Request):
    ip = request.headers.get("X-Real-IP", request.client.host)

    async with db_pool.acquire() as conn:
        user = await conn.fetchrow("SELECT * FROM users WHERE id=$1", uuid.UUID(user_id))
        if not user:
            raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다")

        if req.action == "lock":
            await conn.execute("UPDATE users SET is_locked=true WHERE id=$1", uuid.UUID(user_id))
            await log_audit(user_id, "USER_LOCKED", ip, "medium", {"message": f"계정 잠금: {user['username']}"})
            return {"status": "success", "message": f"{user['username']} 계정이 잠겼습니다"}

        elif req.action == "unlock":
            await conn.execute("UPDATE users SET is_locked=false WHERE id=$1", uuid.UUID(user_id))
            await redis_client.delete(f"login_fail:{user['username']}")
            await log_audit(user_id, "USER_UNLOCKED", ip, "medium", {"message": f"계정 잠금 해제: {user['username']}"})
            return {"status": "success", "message": f"{user['username']} 계정 잠금이 해제되었습니다"}

        elif req.action == "change_role":
            if req.role not in ["admin", "user", "auditor"]:
                raise HTTPException(status_code=400, detail="유효하지 않은 역할입니다 (admin/user/auditor)")
            await conn.execute("UPDATE users SET roles=$1 WHERE id=$2", [req.role], uuid.UUID(user_id))
            await log_audit(user_id, "ROLE_CHANGED", ip, "medium", {"message": f"역할 변경: {user['username']} -> {req.role}"})
            return {"status": "success", "message": f"{user['username']}의 역할이 {req.role}로 변경되었습니다"}

        elif req.action == "delete":
            # 관련 거래 내역 삭제
            accs = await conn.fetch("SELECT id FROM accounts WHERE user_id=$1", uuid.UUID(user_id))
            for acc in accs:
                await conn.execute("DELETE FROM transactions WHERE account_id=$1", acc["id"])
            await conn.execute("DELETE FROM accounts WHERE user_id=$1", uuid.UUID(user_id))
            await conn.execute("DELETE FROM users WHERE id=$1", uuid.UUID(user_id))
            await log_audit(None, "USER_DELETED", ip, "high", {"message": f"회원 삭제: {user['username']}"})
            return {"status": "success", "message": f"{user['username']} 회원이 삭제되었습니다"}

        elif req.action == "edit_info":
            updates = []
            params = []
            idx = 1
            if req.full_name:
                updates.append(f"full_name=${idx}")
                params.append(req.full_name)
                idx += 1
            if req.phone:
                updates.append(f"phone=${idx}")
                params.append(req.phone)
                idx += 1
            if req.username:
                existing = await conn.fetchrow("SELECT id FROM users WHERE username=$1 AND id!=$2", req.username, uuid.UUID(user_id))
                if existing:
                    raise HTTPException(status_code=409, detail="이미 사용 중인 아이디입니다")
                updates.append(f"username=${idx}")
                params.append(req.username)
                idx += 1
            if not updates:
                raise HTTPException(status_code=400, detail="변경할 항목이 없습니다")
            params.append(uuid.UUID(user_id))
            await conn.execute(f"UPDATE users SET {', '.join(updates)} WHERE id=${idx}", *params)
            changed = []
            if req.full_name: changed.append(f"이름:{req.full_name}")
            if req.phone: changed.append(f"연락처:{req.phone}")
            if req.username: changed.append(f"아이디:{req.username}")
            await log_audit(user_id, "USER_INFO_UPDATED", ip, "low", {"message": f"정보 수정: {', '.join(changed)}"})
            return {"status": "success", "message": f"회원 정보가 수정되었습니다 ({', '.join(changed)})"}

    raise HTTPException(status_code=400, detail="유효하지 않은 작업입니다")

# ============ Audit Logs ============

@app.get("/api/v1/auth/audit-logs")
async def get_audit_logs(limit: int = 20):
    async with db_pool.acquire() as conn:
        rows = await conn.fetch(
            "SELECT * FROM audit_logs ORDER BY created_at DESC LIMIT $1", limit)
    logs = []
    for r in rows:
        log = dict(r)
        log["timestamp"] = log.pop("created_at", None)
        if log.get("ip_address"):
            log["ip"] = str(log.pop("ip_address"))
        else:
            log["ip"] = log.pop("ip_address", "")
        logs.append(log)
    return {"logs": logs}

async def log_audit(user_id, action, ip, risk_level, details):
    try:
        async with db_pool.acquire() as conn:
            await conn.execute("""
                INSERT INTO audit_logs (user_id, action, ip_address, risk_level, details, created_at)
                VALUES ($1, $2, $3, $4, $5, $6)
            """, uuid.UUID(user_id) if user_id else None, action, ip, risk_level,
                json.dumps(details, ensure_ascii=False), datetime.utcnow())
    except Exception as e:
        print(f"Audit log error: {e}")

def mask_phone(phone):
    if not phone or len(phone) < 8:
        return phone or ""
    return phone[:3] + "-****-" + phone[-4:]

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
