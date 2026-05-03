"""
계좌조회 서비스 - AES-256-GCM 암호화 + 데이터 마스킹
PCI-DSS Requirement 3.4 준수
"""
import os, base64, secrets, json
from datetime import datetime, timezone
from decimal import Decimal
from typing import Optional

import redis
from fastapi import FastAPI, HTTPException, Request, Query
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

app = FastAPI(title="Fintech Account Service", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

DATABASE_URL = os.getenv("DATABASE_URL", "")
REDIS_URL = os.getenv("REDIS_URL", "")
ENCRYPTION_KEY = os.getenv("ENCRYPTION_KEY", "0" * 64)

engine = create_engine(DATABASE_URL.replace("postgresql://", "postgresql+psycopg2://"))
SessionLocal = sessionmaker(bind=engine)
redis_client = redis.from_url(REDIS_URL, decode_responses=True)

# ── AES-256-GCM ──
def encrypt_data(plaintext: str) -> str:
    key = bytes.fromhex(ENCRYPTION_KEY[:64])
    aesgcm = AESGCM(key)
    nonce = secrets.token_bytes(12)
    ciphertext = aesgcm.encrypt(nonce, plaintext.encode(), None)
    return base64.b64encode(nonce + ciphertext).decode()

def decrypt_data(encrypted: str) -> str:
    try:
        key = bytes.fromhex(ENCRYPTION_KEY[:64])
        aesgcm = AESGCM(key)
        data = base64.b64decode(encrypted)
        return aesgcm.decrypt(data[:12], data[12:], None).decode()
    except:
        return encrypted

def mask_account(number: str) -> str:
    clean = number.replace("-", "").replace("_", "").replace("ENC", "").strip()
    if len(clean) < 4:
        return "****"
    return "****-****-****-" + clean[-4:]

def mask_name(name: str) -> str:
    if not name or len(name) <= 2:
        return name or ""
    return name[0] + "*" * (len(name) - 2) + name[-1]

@app.get("/health")
async def health():
    return {"status": "healthy", "service": "account-service"}

@app.get("/api/v1/accounts/{user_id}")
async def get_accounts(user_id: str):
    db = SessionLocal()
    try:
        results = db.execute(text(
            "SELECT id, account_number_encrypted, account_type, balance, currency "
            "FROM accounts WHERE user_id = :uid AND is_active = true"
        ), {"uid": user_id}).fetchall()

        accounts = []
        for r in results:
            acc_num = decrypt_data(r[1])
            accounts.append({
                "account_id": str(r[0]),
                "account_number": mask_account(acc_num),
                "account_type": r[2],
                "balance": float(r[3]),
                "currency": r[4],
                "encryption": "AES-256-GCM"
            })

        return {"accounts": accounts, "security": {"masking": "applied", "encryption": "AES-256-GCM"}}
    finally:
        db.close()

@app.get("/api/v1/accounts/{user_id}/{account_id}/balance")
async def get_balance(user_id: str, account_id: str):
    cache_key = f"balance:{account_id}"
    cached = redis_client.get(cache_key)

    if cached:
        return {"account_id": account_id, "balance": float(cached), "source": "cache", "ttl": redis_client.ttl(cache_key)}

    db = SessionLocal()
    try:
        result = db.execute(text(
            "SELECT balance FROM accounts WHERE id = :aid AND user_id = :uid"
        ), {"aid": account_id, "uid": user_id}).fetchone()

        if not result:
            raise HTTPException(status_code=404, detail="Account not found")

        balance = float(result[0])
        redis_client.setex(cache_key, 30, str(balance))

        return {"account_id": account_id, "balance": balance, "source": "database", "ttl": 30}
    finally:
        db.close()

@app.get("/api/v1/accounts/{user_id}/{account_id}/transactions")
async def get_transactions(user_id: str, account_id: str, page: int = 1, limit: int = 20):
    db = SessionLocal()
    try:
        owner = db.execute(text(
            "SELECT id FROM accounts WHERE id = :aid AND user_id = :uid"
        ), {"aid": account_id, "uid": user_id}).fetchone()

        if not owner:
            raise HTTPException(status_code=404, detail="Account not found")

        offset = (page - 1) * limit
        results = db.execute(text(
            "SELECT id, transaction_type, amount, balance_after, counterpart_name, "
            "description, status, risk_score, created_at "
            "FROM transactions WHERE account_id = :aid "
            "ORDER BY created_at DESC LIMIT :lim OFFSET :off"
        ), {"aid": account_id, "lim": limit, "off": offset}).fetchall()

        transactions = [{
            "id": str(r[0]),
            "type": r[1],
            "amount": float(r[2]),
            "balance_after": float(r[3]),
            "counterpart": mask_name(r[4]),
            "description": r[5],
            "status": r[6],
            "risk_score": r[7],
            "timestamp": r[8].isoformat() if r[8] else None
        } for r in results]

        return {
            "transactions": transactions,
            "page": page,
            "security": {"name_masking": "applied", "encryption": "AES-256-GCM"}
        }
    finally:
        db.close()
