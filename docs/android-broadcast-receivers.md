# Android broadcast receivers (API 33+)

## Dynamic registration

Android 13+ (enforced on 14+) requires an explicit export flag when calling
`Context.registerReceiver()`:

| Location | Flag | Purpose |
|----------|------|---------|
| `CallkitIncomingActivity` | `RECEIVER_EXPORTED` | Same-app CallKit “call ended” events |
| `CallkitSoundPlayerManager` | `RECEIVER_NOT_EXPORTED` | System `ACTION_SCREEN_OFF` only (stop ringtone) |

## Manifest registration (not affected by `registerReceiver` flags)

| Receiver | `android:exported` | Role |
|----------|-------------------|------|
| `CallDeclineReceiver` | `true` | Native HTTP decline/timeout when app is killed |
| `CallkitIncomingBroadcastReceiver` (plugin) | `true` | Incoming / decline / accept CallKit events |

`CallDeclineReceiver` is **not** registered dynamically; do not move it to
`registerReceiver()` without matching the plugin’s package-scoped broadcast
actions and testing decline with the app killed.

## Call testing after changes

1. Incoming call → decline (app foreground and killed)
2. Incoming call → accept
3. Incoming call → screen off while ringing (ringtone should stop)
