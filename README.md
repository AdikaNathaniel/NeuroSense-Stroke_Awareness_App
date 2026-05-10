<div align="center">

<img src="neurosense_mobile/frontend/neuro-sense.png" alt="NeuroSense" width="140" />

# NeuroSense

**Stroke awareness and on-device risk screening, in your language.**

🔶 _Currently in closed testing — not a medical device, not a substitute for a doctor._

</div>

---

> ## ⚕️ Important Medical Disclaimer
>
> **NeuroSense is _not_ a medical diagnostic tool, and is _not_ a substitute for a qualified clinician.**
> The risk score it produces is an **awareness signal**, not a diagnosis. Every result — regardless of band — directs the user to consult a **General Practitioner** or other healthcare professional for proper evaluation, screening, and care.
>
> The app is currently in **closed testing** with a limited group of users. It is **not yet available on public app stores**, and the analytics, predictions and chat features should be treated as preview functionality.

---

## 📚 Table of Contents

- [The Problem We're Addressing](#-the-problem-were-addressing)
- [Why Ghana, Specifically](#-why-ghana-specifically)
- [Why These Five Languages](#-why-these-five-languages)
- [What the App Does](#-what-the-app-does)
- [Architecture](#%EF%B8%8F-architecture)
- [Local Development](#-local-development)
- [Privacy & Security](#-privacy--security)
- [Roadmap](#%EF%B8%8F-roadmap)
- [Medical Disclaimer](#%EF%B8%8F-medical-disclaimer-1)
- [References](#-references)

---

## 🚨 The Problem We're Addressing

Stroke is the **second leading non-communicable cause of death worldwide** and the **third leading cause of death and disability combined**. According to the World Stroke Organization, approximately **13 million people suffer a stroke each year, of whom around 5.5 million die**. Survivors face long-term disability, reduced quality of life, and substantial care costs for their families.

Strokes happen in two main forms:

| Type | Cause | Share of strokes |
|---|---|---|
| 🩸 **Ischemic** | A blood clot blocks blood flow to part of the brain | ~85% globally |
| 🧬 **Hemorrhagic** | A blood vessel ruptures and bleeds into the brain | ~15% globally, but a much higher share in Sub-Saharan Africa |

The mortality and disability of stroke is **largely preventable** when risk factors (hypertension, diabetes, high glucose, obesity, smoking, atrial fibrillation, age) are identified early and managed. But access to risk-screening clinics — especially in low- and middle-income countries — is uneven, and public awareness of the warning signs is low.

Recent peer-reviewed work (e.g. Islam, Das & Mostofa, _Automated Stroke Prediction and Prevention Recommendations_, IJISRT, August 2025) has shown that **smartphone-delivered, ML-driven risk screening** is feasible and effective for individual-level early identification, even outside of a clinic.

**That is the gap NeuroSense was built for: a private, multilingual, on-device awareness tool that flags elevated stroke risk and tells the user, in their own language, to see a doctor.**

---

## 🇬🇭 Why Ghana, Specifically

The first wave of closed testing is happening in Ghana. The numbers there make the urgency clear:

| Indicator | Value | Source |
|---|---|---|
| 🇬🇭 **National stroke prevalence** | **7.9%** | Attakorah et al., systematic review, 2024 |
| 📈 **Stroke prevalence — adults 50+** | **2.6%** | WHO SAGE, PLOS One |
| 🏥 **Stroke incidence — hypertensive + diabetic Ghanaians** | **14.19 per 1,000 person-years** | Multicenter prospective cohort, PLOS One |
| 📊 **Hospital admission rate, 1983 → 2013** | **5.32 → 13.59 per 1,000 admissions** (2.5× rise) | Ghana national records |
| 💀 **Hospital mortality rate, 1983 → 2013** | **3.4% → 7.6% of all deaths** | Ghana national records |
| 📈 **Stroke cases, 2015 → 2021** | **10,732 → 23,009** (+114%) | Ghana facility records, ScienceDirect 2025 |
| 📈 **Rate change, 2016 → 2021** | **+61%** | Ghana facility records |
| 💀 **8-year case fatality** | **73.7%** | Ghana long-term outcome study |

Stroke in Sub-Saharan Africa is also characterised by **earlier onset, a higher share of hemorrhagic strokes, and significantly worse outcomes** compared to high-income settings — making early warning and patient education materially more valuable.

---

## 🌍 Why These Five Languages

NeuroSense ships with five interface languages. They were chosen deliberately: each corresponds to a population that carries an **outsized stroke burden** relative to global averages.

| 🌐 Language | 🗺 Speaker population | 🩺 Stroke / CVD burden |
|---|---|---|
| 🇬🇧 **English** | Lingua franca; native/official in Ghana, Nigeria, the Caribbean, US, UK | Anchors the project's Ghana pilot; the US "stroke belt" remains one of the highest-mortality stroke regions in any high-income country |
| 🇵🇹 **Portuguese** | Portugal, Brazil, Mozambique, Angola, Cape Verde, Guinea-Bissau | **Portugal historically had the highest stroke mortality in Western Europe**; stroke is/was the leading cause of death there. Brazil and Lusophone Africa carry massive cardiovascular burdens. |
| 🇨🇳 **Chinese (Mandarin)** | China + diaspora (~1.4 B speakers) | **Stroke is the #1 cause of death in China.** 2020 incidence ≈ **505 per 100,000 person-years**; mortality ≈ **343 per 100,000**. China carries the **largest absolute stroke burden of any country**. |
| 🇳🇷 **Nauruan** | Nauru (Pacific) | **Nauru has cardiovascular disease as its #1 cause of mortality** — the highest CVD/NCD burden of any Pacific Island nation. Ischemic stroke mortality is **~76 per 100,000** — 3× neighbouring Guam. |
| 🇲🇭 **Marshallese** | Marshall Islands (Pacific) | Marshall Islands sits alongside Nauru, Tuvalu and Fiji as having **the highest cardiovascular/stroke burden in the Pacific**. NCDs account for ~70% of all deaths in the region. |

The "**global stroke belt**" — eastern Europe, east and southeast Asia, central Africa and Oceania — has up to **10× the age-standardised stroke mortality** of the least-affected countries. NeuroSense's first-launch language list is built specifically to serve four of those five geographies (plus English as the project's working language and Ghana's lingua franca).

> 📝 Translation quality varies by language. Portuguese and Chinese are LLM-translated to a high standard. **Nauruan and Marshallese are low-resource languages in current LLM training data**; the app falls back to English for any term the translator can't confidently produce, and a community review pass is part of the roadmap.

---

## ✨ What the App Does

### 🩺 On-Device Stroke Risk Screening
A trained **TensorFlow Lite model** (`neurosense_model.tflite`, ~8 KB, MLP with batch normalization) runs **fully on the user's phone** — no network call, no data leaves the device. It takes ten clinical inputs:

- Age, gender, marital status, work type, residence type
- Hypertension (Y/N), Heart disease (Y/N)
- Smoking status, average glucose level (mg/dL), BMI (kg/m²)

…and applies the **exact preprocessing pipeline used at training time** (Yeo-Johnson power transform, one-hot encoding, age/glucose/BMI binning, engineered interaction features) before running inference. The output is a probability + risk band:

| 🟢 LOW (0–25%) | 🟠 MEDIUM (25–50%) | 🔴 HIGH (50–75%) | 🟣 CRITICAL (75–100%) |
|---|---|---|---|
| Maintain healthy habits | Lifestyle changes recommended | See a General Practitioner soon | Seek immediate medical attention |

### 📊 Personal Analytics
Each assessment is saved locally (per-user, keyed by email) and surfaces as:

- 📈 **Risk Score Trend** — line chart of assessments over time (tap a point to see the exact %)
- 🍩 **Risk Band Distribution** — donut chart showing how often you've fallen into each band
- 📊 **Vitals vs Healthy Range** — your BMI and glucose plotted against population reference values
- 🧩 **Risk Factor Breakdown** — pie chart of modifiable (BMI, glucose, hypertension, smoking) vs non-modifiable (age, gender, heart disease) factors

### 💬 AI Health Companion
A built-in chat assistant powered by **Anthropic's Claude (via OpenRouter)** with a stroke-awareness system prompt. Users can ask about FAST symptoms, risk factors, prevention strategies, recovery — and the assistant is hard-instructed to recommend emergency services if it detects symptom descriptions.

### 🌍 Multilingual Interface
Five languages, picked from a chip on the register page or from the profile sheet. The full UI batch-translates on first selection via the backend's `/translate` endpoint, then **caches the result on-device** so subsequent switches are instant and work offline.

### 🚨 F.A.S.T. Checker
Quick interactive reminder of the stroke warning signs:
- **F**ace drooping
- **A**rm weakness
- **S**peech difficulty
- **T**ime to call emergency services

### 🔒 Privacy-Conscious Authentication
- Email + OTP verification on signup
- JWT-protected backend (1-hour token)
- Silent re-auth: expired sessions route the user back to the login screen without scary "session expired" error wording
- Bcrypt-hashed passwords (12 rounds), account lockout after 3 failed attempts
- Forgot-password flow via emailed temporary password

### 👤 Profile & Account
- Change password (with current-password verification)
- Switch language at any time
- Log out (wipes token + cached user metadata)

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     📱 Flutter App                          │
│  ┌──────────────┐ ┌──────────────┐ ┌────────────────────┐   │
│  │ TFLite       │ │ Language     │ │ Local History       │  │
│  │ Predictor    │ │ Service +    │ │ (SharedPreferences) │  │
│  │ (on-device)  │ │ Translation  │ │ — per-user          │  │
│  │              │ │ cache        │ │   keyed by email    │  │
│  └──────────────┘ └──────┬───────┘ └────────────────────┘   │
└────────────────────────────│────────────────────────────────┘
                             │
                             ▼ HTTPS
┌─────────────────────────────────────────────────────────────┐
│             🛰  NestJS API  (Fly.io · LAX)                  │
│  /users  • /auth  • /chat  • /translate  • /history         │
│  JWT auth · class-validator · Mongoose                      │
└─────────────────────┬────────────────────────┬──────────────┘
                      ▼                        ▼
            🗄  MongoDB Atlas         🤖 OpenRouter
            (users, history)         (Claude 3.5 Haiku)
                                     • AI Chat
                                     • UI Translation
```

| Layer | Tech |
|---|---|
| 📱 Mobile app | Flutter 3.41 (Dart 3.11) — Android-first, builds for iOS / macOS / Linux / Windows / Web |
| 🧠 On-device inference | `tflite_flutter 0.12` + bundled TF Lite 2.15 runtime |
| 🛰 Backend | NestJS 11 / TypeScript 5 + Mongoose / class-validator |
| 🗄 Database | MongoDB Atlas (users + assessment history) |
| 🤖 LLM provider | OpenRouter → `anthropic/claude-3.5-haiku` (chat + translation) |
| 📦 Deployment | Fly.io (auto-stop machines, LAX region) |
| 🔐 Auth | JWT (Passport) + bcrypt + OTP-via-email |
| 📧 Email | Nodemailer over SMTP (Gmail) |

---

## 🚀 Local Development

> Closed-testing builds are distributed manually; the steps below are for contributors and reviewers.

### Backend

```bash
cd neurosense_mobile/backend
npm install
cp .env.example .env       # fill in MongoDB / SMTP / OpenRouter values
npm run start:dev          # boots on http://localhost:3000
```

### Frontend

```bash
cd neurosense_mobile/frontend
flutter pub get
flutter run                # picks up a connected device or emulator
```

Point the Flutter app at your local backend by editing the `baseUrl` constant in `lib/services/api_service.dart` if you're not using the deployed Fly.io instance.

### ML Model

The TFLite model and preprocessing JSON live in `neurosense_mobile/frontend/assets/mobile-model/` and are bundled with the app. They are exported from the training notebooks (`neurosense.ipynb`, `neurosense_stroke_prediction.ipynb`) at the repo root. If you retrain the model, export both files using the same `feature_order` schema so the on-device preprocessing in `lib/services/local_predictor.dart` matches.

---

## 🔐 Privacy & Security

- 🛡 **Predictions are computed entirely on-device.** The user's age, BMI, glucose, smoking status, hypertension, heart-disease status etc. never leave the phone. Only the resulting probability + categorical features are saved to the user's *local* assessment history.
- 🛡 **Per-user data isolation.** Local history (`SharedPreferences`) is keyed by the logged-in user's email, so multiple accounts on the same device cannot see each other's records.
- 🛡 **No secrets in the repository.** `.env` is gitignored; only `.env.example` (with placeholders) is tracked. Every secret value has been audited across every file before each push.
- 🛡 **Server-side hardening.** JWT (1-hour expiry), bcrypt cost 12, account lockout (3 strikes / 15-min cooldown), OTP-based email verification before login is permitted.
- 🛡 **Silent session re-auth.** Expired JWTs trigger a silent return to the login screen — no confusing "session expired" wording.

---

## 🗺️ Roadmap

NeuroSense is currently in **🔶 Closed Testing**. The plan:

- [x] Phase 1 — MVP build (auth, on-device prediction, AI chat, analytics, FAST checker)
- [x] Phase 2 — Five-language interface (English, Portuguese, Chinese, Nauruan, Marshallese)
- [ ] Phase 3 — Community review pass for Nauruan and Marshallese translations
- [ ] Phase 4 — Tier-2 features (cloud-synced history, profile editing, push reminders to re-screen)
- [ ] Phase 5 — Tier-3 features (nearest-hospital finder via map, share-with-doctor PDF export, offline AI fallback)
- [ ] Phase 6 — Public release (Google Play, Apple App Store)
- [ ] Phase 7 — Clinical validation study (planned in Ghana)

---

## ⚕️ Medical Disclaimer

NeuroSense is an **educational and awareness tool**. It exists to help users recognise modifiable risk factors and understand the F.A.S.T. warning signs of a stroke.

NeuroSense **does not provide a medical diagnosis**. The risk score is generated by a machine-learning model trained on a single open dataset and **should not be used for clinical decision-making**. The categorical bands (LOW / MEDIUM / HIGH / CRITICAL) are awareness labels, not medical classifications.

If you are experiencing any of the F.A.S.T. signs — face drooping, arm weakness, speech difficulty — **stop reading this and call your local emergency services immediately**. Time lost is brain lost.

For all non-emergency concerns about your stroke risk, please consult a **General Practitioner** or other qualified healthcare professional. Every NeuroSense risk band directs you to do exactly that.

---

## 📖 References

1. Islam, M. J., Das, S. C., & Mostofa, M. G. (2025). _Automated Stroke Prediction and Prevention Recommendations: Development of an Android Application._ International Journal of Innovative Science and Research Technology, 10(8), 2661–2674. [doi.org/10.38124/ijisrt/25aug1562](https://doi.org/10.38124/ijisrt/25aug1562)
2. World Stroke Organization. _Global Stroke Fact Sheet 2025._ [PMC11786524](https://pmc.ncbi.nlm.nih.gov/articles/PMC11786524/)
3. Attakorah, J. et al. (2024). _A Systematic Review of the Burden of Stroke in Ghana._ BioMed Research International. [Wiley](https://onlinelibrary.wiley.com/doi/full/10.1155/2024/8298154)
4. Stroke incidence, trends, and geographic disparities in Ghana (2025), Public Health, [ScienceDirect](https://www.sciencedirect.com/science/article/pii/S0033350625000964)
5. Sarfo, F.S. et al. _Incident stroke among Ghanaians with hypertension and diabetes: A multicenter, prospective cohort study._ [PMC6227375](https://pmc.ncbi.nlm.nih.gov/articles/PMC6227375/)
6. Wang, W. et al. _Estimated Burden of Stroke in China in 2020._ JAMA Network Open. [PMC9982699](https://pmc.ncbi.nlm.nih.gov/articles/PMC9982699/)
7. Norrving, B. et al. _Burden of Stroke in Europe._ Stroke (AHA Journals). [STROKEAHA.120.029606](https://www.ahajournals.org/doi/10.1161/STROKEAHA.120.029606)
8. World Bank. _Health & Non-communicable Diseases in the Pacific._ [worldbank.org](https://thedocs.worldbank.org/en/doc/840391465442351786-0070022016/original/PacificPossibleHealthNCD.pdf)
9. Trends and disparities in non-communicable diseases in the Western Pacific region (Pacific NCD burden including Nauru, Marshall Islands), The Lancet. [thelancet.com](https://www.thelancet.com/journals/lanwpc/article/PIIS2666-6065(23)00256-0/fulltext)
10. Howard, G. & Howard, V.J. _Global Stroke Belt._ Stroke (AHA Journals). [strokeaha.115.008226](https://www.ahajournals.org/doi/10.1161/strokeaha.115.008226)
11. Kaggle. _Healthcare Stroke Dataset_ — training data source for the on-device classifier.

---

<div align="center">

🧠 **NeuroSense** — Built with care during closed testing.
Time lost is brain lost. **When in doubt, call a doctor.**

</div>
