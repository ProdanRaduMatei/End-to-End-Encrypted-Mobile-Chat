# Pydantic schemas
from pydantic import BaseModel, EmailStr
from typing import Optional, List

class RegisterReq(BaseModel):
    email: EmailStr
    password: str

class LoginReq(BaseModel):
    email: EmailStr
    password: str

class TokenRes(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: int
    email: EmailStr

class PublicKeyReq(BaseModel):
    public_key_b64: str

class PublicKeyRes(BaseModel):
    user_id: int
    public_key_b64: Optional[str] = None

class SendMessageReq(BaseModel):
    to_user_id: int
    chat_id: str
    nonce_b64: str
    ciphertext_b64: str
    timestamp: int

class MessageOut(BaseModel):
    id: int
    sender_id: int
    receiver_id: int
    chat_id: str
    nonce_b64: str
    ciphertext_b64: str
    timestamp: int

class InboxRes(BaseModel):
    messages: List[MessageOut]