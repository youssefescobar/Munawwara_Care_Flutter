# SOS moderator alert audio

## Behavior

When a pilgrim triggers SOS, moderators hear different audio depending on app state.

| App state | Tray | Sound |
|-----------|------|--------|
| **Foreground** (app open) | **No** tray | Once: `assets/static/urgent_tts.wav` + in-app dialog only |
| **Background / killed / screen off** | Silent visual tray (`mc_sos_v2`) or FCM tray | `urgent_tts.wav` then `assets/audio/sos/{lang}.mp3` |

Language for the background speech clip is read from **prefs at play time** (saved when the user changes language in Settings). Foreground does **not** play language MP3s.

After a language change, profile screens call `await LocalePrefs.saveLanguageCode` and `SosAlertAudio.stopAndReset()` so the next SOS does not overlap old and new language clips.

## Language files

| Code | Asset |
|------|--------|
| `en` | `assets/audio/sos/en.mp3` |
| `ar` | `assets/audio/sos/ar.mp3` |
| `ur` | `assets/audio/sos/ur.mp3` |
| `fr` | `assets/audio/sos/fr.mp3` |
| `id` | `assets/audio/sos/id.mp3` |
| `tr` | `assets/audio/sos/tr.mp3` |

Unknown codes fall back to English.

## Dedupe (one sequence per SOS)

1. **Sync gate** — blocks socket + FCM racing in the same isolate.
2. **Prefs claim** `sos_bundled_claim_v2` — cross-isolate for background sequence.
3. **Main-isolate flag** `sos_main_handled_v1` — background skips if foreground already played urgent.
4. **Coordinator** `_presentationInFlight` — one dialog path per `storageKey`.

Entry points:

- Foreground: `SosAlertAudio.playForegroundUrgentOnly`
- Background FCM: `SosAlertAudio.playBackgroundSequence`

## Related code

| File | Role |
|------|------|
| `lib/core/services/sos_alert_audio.dart` | Foreground urgent + background sequence |
| `lib/core/services/speech_service.dart` | `playAsset`, `stop` |
| `lib/features/moderator/services/sos_alert_coordinator.dart` | Dialog; foreground audio only |
| `lib/core/services/notification_service.dart` | Silent SOS tray + background handler |

Replacing clips: update files under `assets/static/` and `assets/audio/sos/`, then rebuild.

## Manual test checklist

1. Foreground: one `urgent_tts.wav`, dialog, no tray, no language MP3.
2. Background: one urgent wav then one language MP3 (not double urgent if tray is silent).
3. EN → AR in Settings, new SOS: only new language in background sequence.
4. Socket + FCM while foreground: still one urgent wav.
