# SQLAlchemy models
from sqlalchemy import Column, Integer, String, Text, ForeignKey, BigInteger
from sqlalchemy.orm import relationship
from db import Base

class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)

    email = Column(String, unique=True, index=True, nullable=False)
    password_hash = Column(String, nullable=False)

    # base64-encoded X25519 public key
    public_key_b64 = Column(Text, nullable=True)

class Message(Base):
    __tablename__ = "messages"
    id = Column(Integer, primary_key=True, index=True)

    sender_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    receiver_id = Column(Integer, ForeignKey("users.id"), nullable=False)

    chat_id = Column(String, index=True, nullable=False)

    nonce_b64 = Column(Text, nullable=False)
    ciphertext_b64 = Column(Text, nullable=False)

    timestamp = Column(BigInteger, nullable=False)

    sender = relationship("User", foreign_keys=[sender_id])
    receiver = relationship("User", foreign_keys=[receiver_id])