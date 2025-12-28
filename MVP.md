## 📄 Agile MVP Document

## Project: Mini-Signal — End-to-End Encrypted Mobile Chat

---

## 1. Project Overview

Mini-Signal is a mobile messaging application that demonstrates end-to-end encryption (E2EE) for secure communication on mobile devices.
The project focuses on applying modern cryptographic primitives in a real-world mobile security scenario, while explicitly assuming an untrusted backend server.

The application is developed using Flutter for the mobile client and FastAPI for the backend, following Agile principles with an MVP-first approach.

---

## 2. Problem Statement

Most messaging systems rely on centralized servers that can potentially access user data.
This project addresses the following problem:

How can secure communication be achieved on mobile devices when the server is not trusted?

The solution is to implement client-side cryptography, ensuring that only the communicating users can access message contents.

---

## 3. Project Goals

Primary Goals
-	Implement end-to-end encrypted messaging
-	Ensure the server cannot decrypt messages
-	Demonstrate practical use of cryptographic algorithms
-	Align implementation with Cryptography & Arithmetic theory

Secondary Goals
-	Keep the architecture simple and auditable
-	Provide a working demo suitable for academic evaluation
-	Highlight real-world security trade-offs

---

## 4. Target Users
-	Students and academics studying cryptography
-	Mobile developers interested in secure communication
-	Evaluators (professors) assessing applied cryptography projects

---

## 5. MVP Scope Definition

The Minimum Viable Product (MVP) includes only features required to demonstrate secure end-to-end communication.

In Scope
-	User registration and authentication
-	Cryptographic key generation on device
-	Secure key exchange
-	Encrypted message sending and receiving
-	Untrusted backend message relay

Out of Scope (for MVP)
-	Group chats
-	Voice/video calls
-	Push notifications
-	Full anonymity or traffic obfuscation

---

## 6. MVP Features

Authentication
-	Email & password registration
-	JWT-based authentication

Cryptography
-	X25519 for key agreement
-	HKDF-SHA256 for key derivation
-	ChaCha20-Poly1305 for authenticated encryption

Messaging
-	One-to-one chats
-	Encrypted message storage
-	Message integrity verification

---

## 7. High-Level Architecture
-	Mobile Client (Flutter)
-	Performs all cryptographic operations
-	Stores private keys securely on device
-	Backend Server (FastAPI)
-	Stores only public keys, ciphertext, nonces, and metadata
-	Cannot decrypt messages
-	Acts as a relay only

---

## 8. Agile Development Approach
-	Methodology: Agile (iterative, incremental)
-	Sprint length: 1 week
-	MVP delivery: 1–2 sprints

Sprint Structure
-	Planning
-	Implementation
-	Testing
-	Review

---

## 9. MVP Success Criteria

The MVP is considered successful if:
-	Messages are unreadable by the server
-	Decryption fails if ciphertext is modified
-	Keys never leave the mobile device
-	The application runs end-to-end without errors

---

## 10. Risks & Mitigations
```text
Risk                       Mitigation
Incorrect crypto usage     Use well-known libraries
MITM via public keys       Document limitation
Key loss                   Secure storage
Time constraints           Strict MVP scope
```

---

## 11. Deliverables
-	Mobile application (Flutter)
-	Backend service (FastAPI)
-	Source code repository
-	README documentation
-	Agile MVP & MoSCoW documents
-	Demo presentation
