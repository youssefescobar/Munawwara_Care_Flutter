# Pilgrim SOS cancel (moderator sync)

## Purpose

When a pilgrim cancels an active SOS, moderators must clear the blocking dialog,
Active SOS banner, and notification rows immediately — not only on the pilgrim
device.

## Server

- **Socket:** `sos_cancel` with `groupId` / `pilgrimId` (or snake_case variants).
- **HTTP fallback:** `POST /pilgrim/sos/cancel` (optional body: `sos_id`).
- Shared logic lives in `mc_backend_app/services/sos_lifecycle_service.js`:
  - Clears `User.active_sos_id`
  - Deletes `sos_alert` notifications
  - Emits `sos-alert-cancelled` to group + moderator user rooms
  - Sends data-only FCM `sos_alert_cancelled`

## Flutter moderator

- `SosAlertCoordinator.bindCancelListeners()` runs at notification init (not only
  after FCM succeeds) and again when the moderator dashboard connects.
- `handleCancelledFromMap` dismisses the dialog, clears engagement storage, marks
  `hasSOS: false`, and **force**-refreshes the dashboard.

## Flutter pilgrim

- If the socket is connected, emit `sos_cancel`.
- Otherwise call `POST /pilgrim/sos/cancel` via `PilgrimNotifier.cancelSosRemote`.
