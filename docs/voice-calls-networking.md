# Voice calls — why they only work on the same Wi‑Fi

Calls use **two separate networks**:

| Layer | Technology | Needs |
|-------|------------|--------|
| **Signaling** (ring, accept, decline) | Socket.IO + HTTP + FCM | Reachable **backend** URL |
| **Audio** | **Agora** cloud | Valid Agora token from backend; works on any internet |

If calls work on home Wi‑Fi but fail on mobile data or another network, the app is almost always still using a **LAN backend URL** (`192.168.x.x` / `10.0.2.2`), not Agora itself.

## Checklist

### 1. Confirm what URL the app uses

After login, check device logs for:

```text
[Startup] api_base_url=... socketOrigin=...
```

- **Good (internet):** `https://mc-backend-44890250266.europe-west3.run.app/api`
- **LAN-only:** `http://192.168.x.x:5000/api` or `http://10.0.2.2:5000/api`

### 2. Release / Play Store builds

- Set production URL in `.env` **before** `build_and_export.ps1`, **or** use:
  ```bash
  flutter build appbundle --release \
    --dart-define=API_BASE_URL=https://mc-backend-44890250266.europe-west3.run.app/api
  ```
- Do **not** ship QA builds with a commented LAN line active in `.env`.

### 3. Clear stale URL cache

Native call decline/answer caches `api_base_url` in SharedPreferences. After switching from LAN to production:

1. Uninstall the app, **or**
2. Clear app storage, **or**
3. Open the app once with the correct `.env` / production build (prefs refresh on startup).

### 4. Both sides must use the same backend

Caller and callee must hit the **same** API + socket server. Mixed LAN + Cloud Run = no `call-offer`, no Agora token sync.

### 5. Socket.IO on production

`SOCKET_BASE_URL` is optional. When unset, the app uses the same host as `API_BASE_URL` (without `/api`). Production Cloud Run **does** expose Socket.IO (verify: open `/socket.io/?EIO=4&transport=polling` in a browser).

### 6. Agora on the server

Cloud Run must have `AGORA_APP_ID` and `AGORA_APP_CERTIFICATE` (see `mc_backend_app/.env` → `redeploy_cloudrun.ps1`). Client `.env` must use the **same** `AGORA_APP_ID`.

## Symptom → likely cause

| Symptom | Likely cause |
|---------|----------------|
| Works on Wi‑Fi with dev PC running backend; fails on 4G | `API_BASE_URL` points at PC LAN IP |
| Ring sometimes works, accept/connect fails off Wi‑Fi | Socket flaky; check `socketOrigin` logs |
| No ring at all off Wi‑Fi | Wrong API URL or FCM not configured on device |
| Ring + connect UI, no audio | Agora token / certificate mismatch on server |
| Worked after install, broke after dev testing | Cached LAN `api_base_url` in prefs |
| Moderator rings, pilgrim never sees UI (Wi‑Fi + 4G) | **Ghost socket** on server + **FCM not delivered** (see below) |

## GCP logs (production `mc-backend`)

When calls fail everywhere, check Cloud Run logs for:

- `[Socket] Call offer from …` — signaling reaches the server ✓
- `[Socket] call-offer ACK timeout` — pilgrim app did **not** ACK (stale socket or app not listening)
- `[Socket] Recipient … has no fcm_token` — no push fallback
- `FCM Notification sent: 0/1 succeeded` — invalid FCM token (user must reopen app / re-login)
- No `call-answer` / `agora-token` after the offer — call never connected

Backend fix (May 2026): on ACK timeout, evict sockets in `user_<id>` and retry FCM.

App fix: `CallKitService.recoverStaleIncomingCallGuards()` on dashboard load clears stuck ring dedup state.

## In-app call UI (return after leaving the screen)

`VoiceCallScreen` is pushed on top of the dashboard stack. **Swiping back does not end the call** — Agora and `callProvider` stay active.

If you leave the call screen while audio is still connected, a **Return to call** bar appears at the bottom of the app (pilgrim and moderator). Tap it to reopen `VoiceCallScreen`.

| File | Role |
|------|------|
| `lib/features/calling/widgets/active_call_banner.dart` | Global banner when `isInCall` and call UI is not visible |
| `lib/features/calling/call_navigation.dart` | `openVoiceCallScreen()` — single entry for navigation |

## Related code

| File | Role |
|------|------|
| `lib/core/services/api_service.dart` | `API_BASE_URL`, `SOCKET_BASE_URL`, `socketOrigin` |
| `lib/features/calling/call_signaling.dart` | Socket emit + HTTP fallbacks |
| `lib/core/services/agora_rtc_service.dart` | Agora join + `/call-history/agora-token` |
| `lib/features/calling/providers/call_provider.dart` | Call session state (`isInCall`) |
| `mc_backend_app/sockets/socket_manager.js` | `call-offer`, FCM parallel delivery |
