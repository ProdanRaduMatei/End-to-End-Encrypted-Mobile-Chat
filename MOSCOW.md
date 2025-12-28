## 📄 MoSCoW Prioritization Document

### Project: Mini-Signal

---

### MoSCoW Method Overview

The MoSCoW method categorizes features into:
-	Must Have
-	Should Have
-	Could Have
-	Won’t Have (this release)

This ensures clear prioritization and scope control.

---

### 🔴 Must Have (MVP — Mandatory)

These features are essential for the project to function.
-	User registration & login
-	JWT-based authentication
-	On-device cryptographic key generation
-	Public key upload & retrieval
-	Secure key agreement (ECDH)
-	Session key derivation (HKDF)
-	End-to-end encrypted messaging
-	Message integrity verification (AEAD)
-	Untrusted backend design
-	Secure key storage on device

✅ Without these, the project fails its objective

---

### 🟠 Should Have (Important, not critical)

These improve security and usability but are not strictly required.
-	Chat list UI
-	Basic error handling
-	Message timestamps
-	Replay protection (nonces)
-	Clear crypto failure messages

⚠️ Implemented if time allows

---

### 🟡 Could Have (Nice to Have)

These features add polish or advanced security.
-	Forward secrecy via symmetric ratchet
-	Public key fingerprint display
-	QR-code key verification
-	Encrypted local message database
-	Encrypted file attachments

✨ Bonus features for higher grade

---

### ⚫ Won’t Have (Not in MVP)

Explicitly excluded to protect scope.
-	Group chats
-	Voice/video calls
-	Push notifications
-	Full Signal Double Ratchet
-	Traffic padding / anonymity
-	Multi-device sync
-	Cloud backups

❌ Intentionally excluded
