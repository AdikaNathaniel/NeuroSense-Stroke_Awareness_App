# NeuroSense Mobile App — Project Plan
**Date:** 2026-05-09  
**Status:** Planning / Pre-build

---

## Design System

| Token | Value | Usage |
|---|---|---|
| Primary | `#1565C0` (Blue 800) | Buttons, headers, active states, navbar |
| Primary Light | `#1E88E5` (Blue 600) | Hover states, secondary buttons, icons |
| Primary Dark | `#0D47A1` (Blue 900) | App bar, pressed states |
| Accent | `#42A5F5` (Blue 300) | Highlights, risk gauge fill, progress bars |
| Background | `#FFFFFF` (White) | All screen backgrounds |
| Surface | `#F5F9FF` (Blue-tinted white) | Cards, input fields, bottom sheets |
| Text Primary | `#0D1B2A` (Near black) | Body text, headings |
| Text Secondary | `#546E7A` (Blue-grey) | Subtitles, labels, hints |
| Divider | `#E3F2FD` (Blue 50) | Dividers, borders |
| Risk Low | `#43A047` (Green) | Low risk result |
| Risk Medium | `#FB8C00` (Orange) | Medium risk result |
| Risk High | `#E53935` (Red) | High risk result |
| Risk Critical | `#B71C1C` (Dark red) | Critical risk result |

**Font:** Inter (primary) — clean, medical-grade readability  
**Border radius:** 12px (cards), 8px (buttons, inputs)  
**Theme:** Light mode only (MVP)

---

## Tech Stack

| Layer | Decision |
|---|---|
| Mobile Frontend | Flutter (Dart) |
| Backend | NestJS (TypeScript) |
| Database | MongoDB (Mongoose) |
| Auth | JWT + Passport.js + bcrypt |
| Email | Nodemailer (OTP & password reset) |
| ML Model Serving | NestJS calls Python FastAPI microservice (serves neurosense_best_model.joblib) |

---

## Folder Structure

```
neurosense_mobile/
├── frontend/        ← Flutter app
└── backend/         ← NestJS API
```

---

## Auth Features (based on Craftelle pattern)

Full auth is required from day one. No guest mode.

### Screens (Flutter)
| Screen | Description |
|---|---|
| `splash_screen.dart` | Animated intro, check token, route to login or home |
| `register.dart` | Name, email, phone, password, confirm password |
| `otp_page.dart` | 6-digit OTP sent to email after signup — verify before login allowed |
| `login_page.dart` | Email + password, eye toggle, error handling |
| `forgot_password.dart` | Enter email → receive temp password via email |
| `update_password.dart` | Old password + new password + confirm |

### Auth Flow (step by step)

**Signup:**
1. User fills registration form
2. POST `/api/v1/users` → backend hashes password, generates OTP (10 min expiry), saves user as `isVerified: false`, sends OTP email
3. App navigates to OTP screen
4. User enters 6-digit OTP → GET `/api/v1/users/verify-email/:otp/:email`
5. Backend validates OTP + expiry, sets `isVerified: true`
6. App navigates to login

**Login:**
1. User enters email + password
2. POST `/api/v1/users/login`
3. Backend checks: account exists → isActive → not locked → isVerified → password match
4. On fail: increment `failedLoginAttempts` — after 3 failures, lock account for 15 min
5. On success: generate JWT (1h), return token
6. App stores token, navigates to home dashboard

**Forgot Password:**
1. User enters email → GET `/api/v1/users/forgot-password/:email`
2. Backend generates 10-char temp password, hashes + saves it, emails it to user
3. User logs in with temp password, then prompted to update it

**Update Password:**
1. PATCH `/api/v1/users/update-password` with old + new password
2. Backend validates old password matches, hashes new, saves

**Logout:**
1. PUT `/api/v1/users/logout` — clears JWT cookie/token on client

### Backend Auth Modules (NestJS)
| Module | Responsibility |
|---|---|
| `AuthModule` | JWT config, Passport strategy, token generation |
| `UsersModule` | Signup, login, OTP verify, forgot password, update password |
| `EmailModule` | Nodemailer — OTP emails, password reset emails |

### MongoDB User Schema
```
{
  name: String (required),
  email: String (required, unique),
  phone: String (required),
  password: String (hashed, required),
  isVerified: Boolean (default: false),
  otp: String,
  otpExpiryTime: Date,
  failedLoginAttempts: Number (default: 0),
  lockUntil: Date,
  isActive: Boolean (default: true),
  createdAt: Date,
  updatedAt: Date
}
```

### JWT Config
- Secret: `JWT_SECRET` env variable (required)
- Expiry: 1 hour
- Payload: `{ sub: userId, email, username }`
- Guards: `JwtAuthGuard` on all protected routes
- Public routes whitelist: `/login`, `/register`, `/verify-email`, `/forgot-password`

---

## App Features — MVP (Tier 1)

All features below are in scope for the initial build.

| # | Feature | Screen | Notes |
|---|---|---|---|
| 1 | Splash screen | `splash_screen.dart` | Check token → route to home or login |
| 2 | Auth screens | 6 screens above | Full signup/login/reset flow |
| 3 | Risk input form | `risk_assessment.dart` | 10 fields: age, gender, hypertension, heart disease, ever married, work type, residence type, smoking status, avg glucose level, BMI. BMI/glucose helper calculator built in |
| 4 | Prediction result | `result_screen.dart` | Calls ML API, shows probability gauge (0–100%) + 4-tier risk band |
| 5 | 4-tier risk bands | Part of result screen | Low (0–25%) / Medium (25–50%) / High (50–75%) / Critical (75–100%) with color coding |
| 6 | Recommendations | `recommendations.dart` | Tiered: Low → healthy habits. Medium → lifestyle changes. High → see GP. Critical → seek emergency care |
| 7 | FAST checker | `fast_checker.dart` | Interactive Face / Arms / Speech / Time emergency guide |
| 8 | Home dashboard | `home.dart` | Quick links to assessment, FAST checker, education |

---

## App Features — Tier 2 (post-MVP)

| Feature | Notes |
|---|---|
| Assessment history | Save past predictions per user, view trend over time |
| Stroke education library | Info cards: what is a stroke, ischemic vs haemorrhagic, TIA, prevention tips |
| Emergency SOS button | One-tap call to emergency services |
| Profile management | Edit name, phone, password |

---

## App Features — Tier 3 (future)

| Feature | Notes |
|---|---|
| Hospital finder | Map view — nearest hospitals |
| Share with doctor | Export assessment as PDF |
| Push notifications | Monthly reminder to re-check risk |
| Offline mode | Cache last result |

---

## API Endpoints Plan

### Auth
| Method | Endpoint | Description |
|---|---|---|
| POST | `/api/v1/users` | Register |
| GET | `/api/v1/users/verify-email/:otp/:email` | Verify OTP |
| POST | `/api/v1/users/login` | Login |
| PUT | `/api/v1/users/logout` | Logout |
| GET | `/api/v1/users/forgot-password/:email` | Send temp password |
| PATCH | `/api/v1/users/update-password` | Change password |

### Prediction
| Method | Endpoint | Description |
|---|---|---|
| POST | `/api/v1/predict` | Send 10 features → return stroke probability + risk band |

### User
| Method | Endpoint | Description |
|---|---|---|
| GET | `/api/v1/users/profile/:email` | Get profile |
| PATCH | `/api/v1/users/update-profile` | Update name/phone |
| GET | `/api/v1/users/history/:email` | Get assessment history (Tier 2) |

---

## ML Integration

- The NestJS backend calls a **Python FastAPI microservice** that loads `neurosense_best_model.joblib`
- FastAPI endpoint: `POST /predict` — accepts 10 features, returns `{ probability: float, risk_band: string }`
- NestJS acts as the gateway — Flutter never calls the Python service directly
- The Python microservice can be updated (new model) without touching the Flutter app or NestJS API

---

## Reference

Auth implementation modelled on: https://github.com/AdikaNathaniel/Craftelle  
Key files referenced:
- `craftelle_backend/src/users/users.service.ts` — signup, login, OTP, forgot password
- `craftelle_backend/src/auth/jwt.strategy.ts` — JWT validation
- `craftelle_backend/src/shared/middleware/auth.ts` — route protection
- `craftelle_frontend/lib/register.dart` — registration form
- `craftelle_frontend/lib/otp_page.dart` — 6-digit OTP screen
- `craftelle_frontend/lib/login_page.dart` — login with error handling
- `craftelle_frontend/lib/update-password.dart` — password change
