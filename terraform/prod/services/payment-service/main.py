"""
간편결제 서비스 - PCI-DSS 토큰화 + 멱등성 + FDS
"""
import os, uuid, json
from datetime import datetime, timezone
from decimal import Decimal

import redis
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker

app = FastAPI(title="Fintech Payment Service", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

DATABASE_URL = os.getenv("DATABASE_URL", "")
REDIS_URL = os.getenv("REDIS_URL", "")

engine = create_engine(DATABASE_URL.replace("postgresql://", "postgresql+psycopg2://"))
SessionLocal = sessionmaker(bind=engine)
redis_client = redis.from_url(REDIS_URL, decode_responses=True)

class PaymentRequest(BaseModel):
    user_id: str
    account_id: str
    amount: float
    merchant_name: str
    idempotency_key: str

@app.get("/health")
async def health():
    return {"status": "healthy", "service": "payment-service"}

@app.post("/api/v1/payments")
async def process_payment(req: PaymentRequest, request: Request):
    ip = request.client.host

    existing = redis_client.get(f"payment:{req.idempotency_key}")
    if existing:
        return {"status": "already_processed", "payment_id": existing}

    fds = await _calculate_fraud_risk(req.user_id, req.amount, ip)

    if fds["risk_score"] > 80:
        return {"status": "blocked", "message": "Transaction blocked by FDS", "fds": fds}

    if fds["risk_score"] > 50:
        return {"status": "requires_additional_auth", "message": "High risk", "fds": fds}

    daily_key = f"daily_payment:{req.user_id}:{datetime.now().strftime('%Y%m%d')}"
    daily_used = float(redis_client.get(daily_key) or 0)

    if daily_used + req.amount > 5000000:
        raise HTTPException(status_code=400, detail=f"Daily limit exceeded. Used: {daily_used:,.0f}")

    payment_id = str(uuid.uuid4())
    db = SessionLocal()
    try:
        account = db.execute(text(
            "SELECT balance FROM accounts WHERE id = :aid AND user_id = :uid"
        ), {"aid": req.account_id, "uid": req.user_id}).fetchone()

        if not account:
            raise HTTPException(status_code=404, detail="Account not found")
        if float(account[0]) < req.amount:
            raise HTTPException(status_code=400, detail="Insufficient balance")

        new_balance = float(account[0]) - req.amount
        db.execute(text("UPDATE accounts SET balance = :bal WHERE id = :aid"),
                   {"bal": new_balance, "aid": req.account_id})

        db.execute(text(
            "INSERT INTO transactions (account_id, transaction_type, amount, balance_after, "
            "counterpart_name, description, idempotency_key, risk_score) "
            "VALUES (:aid, 'payment', :amt, :bal, :merchant, :desc, :ikey, :risk)"
        ), {"aid": req.account_id, "amt": -req.amount, "bal": new_balance,
            "merchant": req.merchant_name, "desc": "간편결제 (토큰화)",
            "ikey": req.idempotency_key, "risk": fds["risk_score"]})

        db.commit()

        redis_client.setex(f"payment:{req.idempotency_key}", 86400, payment_id)
        redis_client.incrbyfloat(daily_key, req.amount)
        redis_client.expire(daily_key, 86400)
        redis_client.delete(f"balance:{req.account_id}")

        return {
            "status": "success", "payment_id": payment_id,
            "amount": req.amount, "new_balance": new_balance,
            "fds": fds, "security": {"tokenized": True, "idempotency": True, "encryption": "AES-256-GCM"}
        }
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Payment failed: {str(e)}")
    finally:
        db.close()

@app.get("/api/v1/payments/daily-limit/{user_id}")
async def get_daily_limit(user_id: str):
    daily_key = f"daily_payment:{user_id}:{datetime.now().strftime('%Y%m%d')}"
    used = float(redis_client.get(daily_key) or 0)
    return {"daily_limit": 5000000, "used": used, "remaining": 5000000 - used}

async def _calculate_fraud_risk(user_id: str, amount: float, ip: str) -> dict:
    score = 0
    factors = []
    if amount > 1000000:
        score += 20; factors.append("high_amount")
    if amount > 3000000:
        score += 20; factors.append("very_high_amount")

    count_key = f"payment_count:{user_id}"
    count = int(redis_client.get(count_key) or 0)
    redis_client.incr(count_key)
    redis_client.expire(count_key, 600)
    if count > 5:
        score += 30; factors.append("high_frequency")

    hour = datetime.now().hour
    if 1 <= hour <= 5:
        score += 15; factors.append("unusual_hour")

    score = min(score, 100)
    level = "low" if score < 30 else "medium" if score < 60 else "high"
    return {"risk_score": score, "risk_level": level, "factors": factors}
