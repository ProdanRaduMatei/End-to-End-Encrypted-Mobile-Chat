# 🔐 Mini-Signal
## End-to-End Encrypted Mobile Chat Application

**Mini-Signal** is a secure mobile messaging application that demonstrates **end-to-end encryption (E2EE)** on mobile devices using modern cryptographic primitives.  
The system is designed so that the **backend server is untrusted** and **never has access to plaintext messages or cryptographic keys**.

This project was developed for the **Cryptography and Arithmetic** university course under the topic **Security of Mobile Devices**.

---

## 📌 Key Features

- 🔒 **End-to-End Encryption (E2EE)** — messages are encrypted on the sender’s device and decrypted only on the receiver’s device
- 🔑 **Elliptic-Curve Diffie–Hellman (X25519)** for secure key agreement
- 🧮 **HKDF-SHA256** for cryptographic key derivation
- 🛡 **Authenticated Encryption (ChaCha20-Poly1305)** for confidentiality and integrity
- 📱 **Mobile-first implementation** using Flutter
- 🌐 **Untrusted backend** (FastAPI) acting only as a message relay
- 🗃 **Secure key storage** on the mobile device

---

## 🖥 Server Role (Threat Model)

- Stores **only ciphertext, nonces, and minimal metadata**
- **Cannot decrypt messages**
- Does **not** have access to private keys
- Treated as a **potentially malicious adversary**

---

## 🏗 System Architecture

```text
┌──────────────┐        HTTPS        ┌────────────────┐
│   Flutter    │ ─────────────────▶  │   FastAPI      │
│   Client     │                     │   Backend      │
│ (Trusted)    │ ◀─────────────────  │ (Untrusted)    │
└──────────────┘                     └────────────────┘
        │                                    │
        │                                    │
  Crypto performed                      Stores only:
  entirely on device                    • Public keys
                                        • Ciphertext
                                        • Nonces
                                        • Metadata
```
•	All cryptographic operations are performed exclusively on the mobile device
•	The backend acts strictly as a dumb message relay

---

## 🧠 Cryptographic Design

🔑 Identity Keys

Each user generates a long-term X25519 key pair:
-	The private key never leaves the device
-	The public key is uploaded to the server

🔄 Session Key Establishment

When a chat is initiated:
1.	Public keys are exchanged via the server
2.	A shared secret is computed using ECDH (X25519)
3.	A symmetric session key is derived using HKDF-SHA256

🔐 Message Encryption
-	Messages are encrypted using ChaCha20-Poly1305 (AEAD)
-	A fresh nonce is generated for every message
-	Additional authenticated data (AAD) binds message metadata

🧾 Server Knowledge

The server sees only encrypted message blobs and cannot infer message contents.

---

## 🛠 Technology Stack

Frontend (Mobile)
-	Flutter
-	cryptography package
-	flutter_secure_storage
-	HTTP REST API

Backend
-	FastAPI
-	SQLite (for simplicity)
-	JWT authentication
-	SQLAlchemy ORM

---

## 📁 Repository Structure
```text
mini-signal/
├── backend/
│   ├── main.py            # FastAPI entry point
│   ├── auth.py            # JWT authentication & password hashing
│   ├── models.py          # SQLAlchemy models
│   ├── schemas.py         # Pydantic schemas
│   ├── db.py              # Database setup
│   └── requirements.txt
│
├── flutter_app/
│   ├── lib/
│   │   ├── crypto_service.dart   # E2EE cryptographic logic
│   │   ├── api.dart              # REST API client
│   │   ├── auth_store.dart       # Secure key & token storage
│   │   └── screens/
│   │       ├── login.dart
│   │       ├── users.dart
│   │       └── chat.dart
│
├── .gitignore
└── README.md
```

---

## 🚀 Getting Started

1️⃣ Backend Setup
```text
cd backend
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
```
Backend will run at:
```text
http://localhost:8000
```
---

## 2️⃣ Flutter App Setup
```text
cd flutter_app
flutter pub get
flutter run
```
⚠️ Ensure the backend URL in api.dart points to your local machine.

---

## 🔐 Security Properties Achieved
```text
Property                      Status      Explanation
Confidentiality                 ✅        Only sender and receiver can read messages
Integrity                       ✅        AEAD detects any message tampering
Authentication                  ✅        Keys are cryptographically bound to users
Server Trust Minimization       ✅        Server cannot decrypt or forge messages
Forward Secrecy            ⚠️ Partial     Single session key per chat (ratchet optional)
```

---

## ⚠️ Known Limitations
-	Metadata leakage: the server can observe communication patterns and timestamps
-	No public-key verification UI: vulnerable to server-side MITM attacks
-	No full Double Ratchet: protocol intentionally simplified
-	No anonymity or traffic padding

These limitations are explicitly acknowledged and kept for educational clarity.

---

## 🎓 Academic Relevance

This project demonstrates:
-	Practical use of elliptic-curve arithmetic
-	Secure key agreement and derivation
-	Authenticated encryption in mobile systems
-	Real-world constraints of mobile cryptography
-	Clear separation between trusted clients and untrusted infrastructure

---

## 🧪 Possible Extensions
-	Symmetric or Double Ratchet (forward secrecy)
-	QR-code public-key verification
-	Encrypted local message storage
-	Encrypted file attachments
-	Biometric-protected key access

---

## 👤 Author

Matei Prodan, Vlad Stoian, Andrei Voinea
MSc Applied Computational Intelligence
Babeș-Bolyai University
Cryptography and Arithmetic — Mobile Security Project

---

## 📜 License

This project is intended for educational and academic use only.
