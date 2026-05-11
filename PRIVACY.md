# NeuroSense — Privacy Policy

**Effective date:** 11 May 2026
**App:** NeuroSense — Stroke Awareness & Risk Screening
**Package name:** `com.adikanathaniel.neurosense`
**Stage:** Closed testing

This Privacy Policy explains what information **NeuroSense** ("the app", "we", "us") collects from you, why we collect it, where we store it, who we share it with, and what choices you have about it.

NeuroSense is currently in **closed testing**. Some features may change before public release. We will update this policy when they do and publish the new version at the same URL.

---

## 1. The short version

- We collect **only what we need** to let you sign in, get a risk score, and use the AI chat.
- Your **stroke-risk inputs** (age, BMI, glucose, hypertension, smoking, etc.) are processed **entirely on your device**. They are **never sent to our backend** or to any third party.
- Your **assessment history** is stored **on your phone only** (in encrypted app storage), not in any cloud database.
- We do **not** sell your data.
- We do **not** use third-party analytics, advertising SDKs, or tracking pixels.
- NeuroSense is **not a medical device** and **not a substitute for a doctor**.

---

## 2. What we collect

### 2.1 Information you give us at sign-up
When you create a NeuroSense account, we collect:

| Field | Why we need it |
|---|---|
| **Name** | To greet you in the app and on emails. |
| **Email address** | To verify your account (one-time OTP), to send password-reset emails, and to identify you on subsequent logins. |
| **Phone number** | Recorded with your account profile. We do **not** call you, SMS you, or share your phone number. It is stored for support-contact purposes only. |
| **Password** | Stored only as a **bcrypt hash** (cost 12) on our backend. The plaintext is never stored or logged. |

### 2.2 Information you give us during use
- **AI Chat messages**: anything you type into the AI Chat tab is sent to our backend over HTTPS so the model can reply. See §4 for how it's handled.
- **Language preference**: the language you pick in the language menu is sent to our backend **once** so the UI can be translated. After the first translation it is cached on your device and no further network calls are made for that language.

### 2.3 Information generated on your device (not sent to us)
The following data **stays on your phone**:

- Your age, gender, marital status, work type, residence type, hypertension status, heart-disease status, average glucose level, BMI, and smoking status — entered into the **Risk Assessment** form.
- The probability score and risk band produced by the on-device TensorFlow Lite model.
- Your full **assessment history** (used by the Analytics tab) — stored in your app's local `SharedPreferences`, keyed by your email address so multiple accounts on the same device do not see each other's records.

### 2.4 Permissions the app does NOT request
For transparency: NeuroSense does **not** request access to your contacts, photos, microphone, camera, GPS / location, calendar, SMS, call log, phone state, external storage, or installed apps. It also does **not** access your phone's IMEI, advertising ID, or SIM details.

The app does request `android.permission.INTERNET`, which is required for the chat and translation features.

---

## 3. What we do with it

| What we collect | What we do with it |
|---|---|
| Name, email, phone | Account creation, authentication, password reset, support. |
| Password (hash) | Verify you on login. We can never see your plaintext password. |
| OTP (6-digit, 10-min expiry) | Verify your email address once on signup. Deleted after verification. |
| Failed login attempts, lock timer | Protect your account from brute-force attacks. We auto-lock for 15 min after 3 failed attempts. |
| JWT auth token | Keep you signed in for 1 hour at a time; stored in your phone's secure storage. |
| AI Chat messages | Forwarded to our LLM provider so the assistant can reply (see §4). |
| Language preference | One-off batch translation of the UI strings, cached on-device afterwards. |

We do **not** profile you, target advertising, or build a behavioural dossier.

---

## 4. Who we share it with

NeuroSense uses three third-party providers, each strictly limited to what the feature needs:

### 4.1 MongoDB Atlas
- **What it stores:** your account record (name, email, phone, hashed password, OTP, lock state, timestamps).
- **Where:** managed cluster (US region) operated by MongoDB Inc.
- **Why:** we need a place to persist your account so you can log in from any device.

### 4.2 OpenRouter → Anthropic Claude (AI Chat + UI Translation)
- **What is sent:** the message text you type into the AI Chat, OR the list of English UI strings to translate when you change language.
- **Why:** the AI model runs there and generates the reply / translation.
- **What is NOT sent:** your name, email, password, JWT, phone number, or any of your health inputs.
- **Provider policies:** see [OpenRouter Privacy](https://openrouter.ai/privacy) and [Anthropic Privacy](https://www.anthropic.com/legal/privacy).

### 4.3 Fly.io (hosting)
- The backend (`neurosense-api`) runs on Fly.io infrastructure (Los Angeles, USA). Request logs may transiently include your IP address.
- See [Fly.io Privacy](https://fly.io/legal/privacy-policy/).

### 4.4 Gmail SMTP (transactional email)
- We use Gmail SMTP to deliver your OTP and password-reset emails. The email contains your name, the OTP code, and the NeuroSense branding.

We do **not** share your information with advertisers, data brokers, analytics companies, or any other third party.

---

## 5. Where data lives, and for how long

| Data | Location | Retention |
|---|---|---|
| Account record (name, email, hashed password, phone) | MongoDB Atlas (US) | Until you ask us to delete it (see §7). |
| OTP | MongoDB Atlas | Auto-deleted after verification or 10 minutes, whichever is first. |
| JWT token | Your phone's secure storage | 1 hour, then auto-expires. |
| Risk assessment inputs + history | **Your phone only** (`SharedPreferences`) | Until you uninstall the app or log out. We have no copy. |
| AI Chat messages | Live in transit only | We do not log chat content on our backend. OpenRouter/Anthropic may retain prompts per their own policies — please review their links above. |
| Server access logs | Fly.io | Per Fly.io's retention. |

---

## 6. Security

- Passwords are **bcrypt-hashed** with cost factor 12 before they hit the database.
- Authentication tokens are stored using **Android Keystore / iOS Keychain** via `flutter_secure_storage`.
- All communication between the app and our backend uses **HTTPS / TLS**.
- Three failed login attempts triggers a **15-minute account lockout**.
- We never store production credentials in source control. `.env` files are git-ignored; only template files are tracked.

No system is perfectly secure. If you believe your account has been compromised, contact us at the address in §10 and we will help you reset.

---

## 7. Your rights

You can:

- **Change your password** at any time from the Profile tab (Person icon → Change Password).
- **Log out** at any time from the Profile tab — this wipes your local token, cached language, and locally-stored email/name.
- **Request account deletion** by emailing us (see §10). We will permanently delete your account record from MongoDB Atlas within 30 days of a confirmed request.
- **Request a copy of your data** by emailing us. Since most of your data already lives only on your phone, we will provide whatever account-level fields remain on the server.

Local data (risk history, language cache) can be cleared instantly by uninstalling the app or logging out and choosing a different account.

---

## 8. Children's privacy

NeuroSense is intended for adults (18+). We do not knowingly collect personal information from anyone under 18. If you believe a minor has registered an account, please contact us and we will delete it.

---

## 9. International data transfers

If you are using NeuroSense from outside the United States, please be aware that your account record is processed in the United States (MongoDB Atlas, Fly.io). By creating an account you consent to this transfer.

---

## 10. Contact

Questions, deletion requests, data-export requests, or privacy concerns:

- **GitHub Issues**: [github.com/AdikaNathaniel/NeuroSense-Stroke_Awareness_App/issues](https://github.com/AdikaNathaniel/NeuroSense-Stroke_Awareness_App/issues)
- **Email**: open an issue using the link above and request a private reply.

---

## 11. Changes to this policy

We will update this policy as the app evolves (cloud history sync, push notifications, additional providers, etc.). The "Effective date" at the top will change, and material changes will be announced in the app on next launch.

---

## 12. Medical disclaimer

NeuroSense is an **awareness tool**, **not** a medical device, and **not** a substitute for a qualified healthcare professional. The risk score produced by the app is not a diagnosis. If you are experiencing symptoms of a stroke — face drooping, arm weakness, speech difficulty — **call your local emergency services immediately**. For non-emergency concerns, please consult a General Practitioner or other qualified clinician.
