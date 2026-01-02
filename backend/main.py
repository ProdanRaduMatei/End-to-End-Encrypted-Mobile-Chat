# FastAPI entry point
from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from db import Base, engine, SessionLocal
from models import User, Message
from schemas import (
    RegisterReq, LoginReq, TokenRes,
    PublicKeyReq, PublicKeyRes,
    SendMessageReq, InboxRes, MessageOut
)
from auth import hash_password, verify_password, create_access_token, get_current_user_id
from time import time
from urllib.parse import unquote

app = FastAPI(title="Mini-Signal Backend")

# ✅ allow calls from emulator/phone/ipad while developing
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],   # for dev only
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

Base.metadata.create_all(bind=engine)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@app.get("/health")
def health():
    return {"ok": True, "ts": int(time())}

@app.post("/register", response_model=TokenRes)
def register(req: RegisterReq, db: Session = Depends(get_db)):
    existing = db.query(User).filter(User.email == req.email).first()
    if existing:
        raise HTTPException(status_code=400, detail="Email already registered")

    u = User(email=req.email, password_hash=hash_password(req.password))
    db.add(u)
    db.commit()
    db.refresh(u)

    token = create_access_token({"user_id": u.id, "email": u.email})
    return TokenRes(access_token=token, user_id=u.id, email=u.email)

@app.post("/login", response_model=TokenRes)
def login(req: LoginReq, db: Session = Depends(get_db)):
    u = db.query(User).filter(User.email == req.email).first()
    if not u or not verify_password(req.password, u.password_hash):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    token = create_access_token({"user_id": u.id, "email": u.email})
    return TokenRes(access_token=token, user_id=u.id, email=u.email)

@app.post("/keys", response_model=PublicKeyRes)
def upload_public_key(
        req: PublicKeyReq,
        user_id: int = Depends(get_current_user_id),
        db: Session = Depends(get_db)
):
    u = db.query(User).filter(User.id == user_id).first()
    if not u:
        raise HTTPException(status_code=404, detail="User not found")

    u.public_key_b64 = req.public_key_b64
    db.add(u)
    db.commit()
    return PublicKeyRes(user_id=u.id, public_key_b64=u.public_key_b64)

@app.get("/keys/{target_user_id}", response_model=PublicKeyRes)
def get_public_key(
        target_user_id: int,
        _user_id: int = Depends(get_current_user_id),
        db: Session = Depends(get_db)
):
    u = db.query(User).filter(User.id == target_user_id).first()
    if not u:
        raise HTTPException(status_code=404, detail="User not found")
    return PublicKeyRes(user_id=u.id, public_key_b64=u.public_key_b64)

@app.get("/users")
def list_users(
        _user_id: int = Depends(get_current_user_id),
        db: Session = Depends(get_db)
):
    users = db.query(User).all()
    return [{"id": u.id, "email": u.email, "hasKey": bool(u.public_key_b64)} for u in users]

@app.post("/messages/send")
def send_message(
        req: SendMessageReq,
        sender_id: int = Depends(get_current_user_id),
        db: Session = Depends(get_db)
):
    if req.to_user_id == sender_id:
        raise HTTPException(status_code=400, detail="Cannot message yourself")

    receiver = db.query(User).filter(User.id == req.to_user_id).first()
    if not receiver:
        raise HTTPException(status_code=404, detail="Receiver not found")

    m = Message(
        sender_id=sender_id,
        receiver_id=req.to_user_id,
        chat_id=req.chat_id,
        nonce_b64=req.nonce_b64,
        ciphertext_b64=req.ciphertext_b64,
        timestamp=req.timestamp,
    )
    db.add(m)
    db.commit()
    db.refresh(m)
    return {"ok": True, "message_id": m.id}

@app.get("/messages/inbox", response_model=InboxRes)
def inbox(
        user_id: int = Depends(get_current_user_id),
        db: Session = Depends(get_db)
):
    msgs = (
        db.query(Message)
        .filter(Message.receiver_id == user_id)
        .order_by(Message.timestamp.asc())
        .all()
    )
    out = [
        MessageOut(
            id=m.id,
            sender_id=m.sender_id,
            receiver_id=m.receiver_id,
            chat_id=m.chat_id,
            nonce_b64=m.nonce_b64,
            ciphertext_b64=m.ciphertext_b64,
            timestamp=m.timestamp,
        )
        for m in msgs
    ]
    return InboxRes(messages=out)

@app.get("/users/by-email/{email}")
def get_user_by_email(
        email: str,
        _user_id: int = Depends(get_current_user_id),
        db: Session = Depends(get_db)
):
    # email comes URL-encoded sometimes
    email = unquote(email).strip().lower()

    u = db.query(User).filter(User.email == email).first()
    if not u:
        raise HTTPException(status_code=404, detail="User not found")

    return {
        "id": u.id,
        "email": u.email,
        "public_key_b64": u.public_key_b64,
        "hasKey": bool(u.public_key_b64),
    }