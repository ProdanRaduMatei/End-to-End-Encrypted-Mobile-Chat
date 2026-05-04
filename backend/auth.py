# JWT authentication & password hashing
from passlib.context import CryptContext
from jose import jwt, JWTError
from datetime import datetime, timedelta
from fastapi import HTTPException, status, Depends
from fastapi.security import OAuth2PasswordBearer

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# ✅ CHANGE THIS BEFORE DEMO/SUBMISSION
SECRET_KEY = "CHANGE_ME_TO_A_LONG_RANDOM_SECRET"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/login")

def hash_password(password: str) -> str:
    return pwd_context.hash(password)

def verify_password(password: str, password_hash: str) -> bool:
    return pwd_context.verify(password, password_hash)

def create_access_token(data: dict) -> str:
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

def decode_token(token: str) -> dict:
    try:
        return jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token",
        )

def get_current_user_id(token: str = Depends(oauth2_scheme)) -> int:
    payload = decode_token(token)
    uid = payload.get("user_id")
    if uid is None:
        raise HTTPException(status_code=401, detail="Invalid token payload")
    return int(uid)