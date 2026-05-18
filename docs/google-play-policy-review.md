# Munawwara Care — Google Play: remaining work

**Purpose:** What is still required before / during Play submission.  
**App:** Munawwara Care (Flutter Android) + `mc_backend_app` + `mc_mod_front`.  
**Last updated:** May 18, 2026

Completed in-app / manifest work (package rename, cleartext, permission cleanup, in-app privacy/support/deletion forms, SOS disclaimers, Firebase project `munawwaracare-5353a`) is **not** listed here unless you still need to verify it in Console.

---

## Critical — block production / Play approval

| # | Item | What to do |
|---|------|------------|
| 1 | **Play Data safety form** | Complete in Play Console: precise + **background** location, audio (calls), personal/health fields (medical history, visa, etc.), device IDs, FCM. **Do not** declare crash/analytics — app has none. |
| 2 | **Background location** | In-app disclosure exists; still need **Data safety** + store listing text + **background location video** (Play requirement) aligned with pilgrim safety use case. |
| 3 | **Privacy Policy (live site)** | Update https://saifisvibinn.github.io/munawwara-privacy/ — see checklist below. Must match app + Data safety. |
| 4 | **Brand / trademark** | Written authorization from Munawwara Care for store name, icon, and listing (freelancer ≠ brand owner). |
| 5 | **Store listing assets** | 512×512 icon, feature graphic 1024×500, phone screenshots (show location disclosure / SOS / calls if you claim those features). |
| 6 | **Firebase FCM (backend)** | Service account on **`munawwaracare-5353a`** needs **Firebase Cloud Messaging API Admin** (or equivalent). Logs must show `FCM Notification sent: 1/1 succeeded`, not `cloudmessaging.messages.create denied`. |
| 7 | **Deploy backend** | Ship `POST /api/support/request` and latest env (Firebase `munawwaracare-5353a`) to **Cloud Run** if not already deployed. |

---

## High priority

| # | Item | What to do |
|---|------|------------|
| 8 | **App access (reviewers)** | Play Console → App access: moderator test account + **fresh** pilgrim one-time code/QR (device-bound). Note reissue if code fails. |
| 9 | **Support email on store listing** | List **munawwaracare@gmail.com** on Play store listing (in-app forms already email this address). |
| 10 | **Privacy policy — deletion/support copy** | Site should say pilgrims use in-app **تواصل مع الدعم** / **Request account deletion** (not mailto-only). See checklist below. |
| 11 | **Target audience** | Play Console: **not designed for children under 13**; operator policy if minors are provisioned. |
| 12 | **Pre-launch report** | Run internal testing track; fix crashes/permission issues on **targetSdk 36**. |

---

## Medium priority

| # | Item | What to do |
|---|------|------------|
| 13 | **Data residency** | Confirm **MongoDB Atlas** and **Firebase** regions; add to privacy policy (API is `europe-west3`). |
| 14 | **Group delete vs account delete** | Document on privacy site: deleting a **group** unassigns pilgrims; full removal = moderator **Delete pilgrim account** or in-app deletion request. |
| 15 | **API keys in APK** | Restrict **Agora** and **Google Maps** keys in cloud consoles (package `com.munawwaracare.android`). |
| 16 | **Category & positioning** | Store category (e.g. Travel); avoid medical-device claims — use “group safety / coordination.” |
| 17 | **UGC / communication** | Moderator-only messaging — ensure Terms/privacy mention moderation and **munawwaracare@gmail.com**. |

---

## Play Console checklist (manual)

- [ ] Data safety form submitted  
- [ ] Background location declaration + **video** uploaded  
- [ ] Privacy policy URL set and content updated  
- [ ] Store listing: short/full description, screenshots, feature graphic  
- [ ] App access credentials for reviewers  
- [ ] Target audience / not for children (13+)  
- [ ] Financial features: **No** (no IAP, no ads)  
- [ ] Internal testing → closed/open when ready  

---

## Privacy policy site checklist

Update https://saifisvibinn.github.io/munawwara-privacy/ :

1. **Remove** crash/diagnostics claims (no Analytics/Crashlytics in app).  
2. **Add** providers: Agora, GCP Cloud Run, MongoDB Atlas, Redis, GCS, Translation/TTS, FCM, Gmail SMTP.  
3. **Clarify** messages are **moderator-sent** (pilgrim inbox read-only).  
4. **List** data: medical history, visa, hotel/room/bus, battery %, device binding, background location, call metadata.  
5. **Account deletion:** pilgrims — in-app *Request account deletion* or **munawwaracare@gmail.com**; moderators — removed by org admin.  
6. **Group delete** vs **Delete pilgrim account** (see item 14 above).  
7. **Disclaimer:** not medical advice; not emergency services (999/911); SOS alerts the **group moderator**.  
8. **Contact:** **munawwaracare@gmail.com** and in-app support form.

---

## Suggested store copy (drafts)

**Short description (≤80 chars)**  
> Safety app for Hajj & Umrah groups: live location, SOS, chat & calls with your guide.

**Reviewer notes (App access)**  
1. Moderator: email + password (test account you provide).  
2. Pilgrim: fresh one-time code or QR (not bound to another device).  
3. Grant **location (Always)** and **notifications**; complete device-care onboarding if shown.  
4. Test VoIP call and SOS from pilgrim.  
5. API: `https://mc-backend-44890250266.europe-west3.run.app/api`

---

## Verify before upload (quick smoke)

| Check | Expected |
|-------|----------|
| Release APK package | `com.munawwaracare.android` |
| `PUT /api/auth/fcm-token` after login | **200** in Cloud Run logs |
| Test call → FCM log | `1/1 succeeded` |
| Profile → Contact support / Deletion | Form submits; email received at support inbox |
| Privacy policy | Opens in-app WebView |

---

## Completed (in repo — May 2026)

Record of work already done in the codebase. Re-verify in Play Console / production where noted.

### Android manifest & build

| Item | Done |
|------|------|
| `applicationId` / namespace | `com.munawwaracare.android` (was `…andriod`) |
| Kotlin package + method channels + CallKit receivers | Renamed to `com.munawwaracare.android` |
| `google-services.json` | Firebase project `munawwaracare-5353a`, package `com.munawwaracare.android` |
| `usesCleartextTraffic` | `false` in release; `true` in debug only |
| Removed permissions | `BATTERY_STATS`, `SYSTEM_ALERT_WINDOW`, `CALL_PHONE`; duplicate `FOREGROUND_SERVICE` deduped |
| `<queries>` | https, http, mailto, common browsers (for optional external links) |

### In-app legal & UX (pilgrim + moderator Settings)

| Item | Done |
|------|------|
| Privacy Policy | In-app WebView → GitHub Pages URL |
| Contact support | In-app form → `POST /api/support/request` → emails support |
| Request account deletion | Confirm dialog → in-app form (same API, type `account_deletion`) |
| SOS / safety copy | Home tab banner + updated strings (6 locales) |
| Agora disclosure | Shown in legal section |
| Arabic label | Contact support = **تواصل مع الدعم** |

### Backend (local / partial prod)

| Item | Done |
|------|------|
| Firebase Admin env | `FIREBASE_*` for `munawwaracare-5353a` in `.env` |
| Support API | `POST /api/support/request` + `sendSupportInquiryEmail` |
| FCM token upload guard | Auth required; no logout on `fcm-token` 401 |

### Still verify on production

- Cloud Run env matches `munawwaracare-5353a` + support route deployed  
- FCM IAM → `FCM Notification sent: 1/1 succeeded`  
- Release APK smoke (calls, support forms, fcm-token **200**)

### Payments / content (unchanged — still compliant)

- No ads, no IAP, no Play Billing  
- No AccessibilityService  
- Firebase client: FCM only (no Analytics/Crashlytics in repo)  
- HTTPS production API: `mc-backend-44890250266.europe-west3.run.app`

---

*Compliance aid only — not legal advice.*
