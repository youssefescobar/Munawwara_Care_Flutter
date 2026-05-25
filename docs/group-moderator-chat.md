# Moderator group chat (broadcasts)

## Screen

- **Route:** `GroupMessagesScreen` from group card **Chat** or notifications.
- **Layout:** `GroupChatHeader` + message list + composer (TTS / voice). No pilgrim filter strip (empty filter row caused top message cutoff).

## Unread counts

- Dashboard API provides `unread_count` per group.
- Socket `new_message` increments via `moderatorProvider.incrementUnreadCount` when not viewing that chat.
- Opening chat calls `clearUnreadCount` and `markAllRead`.

## Delete messages

- Any **group moderator** may delete any message in that group (text, voice, TTS, meetpoint) via `DELETE /api/messages/:message_id`.
- UI: trash on each card + long-press menu → delete.
- **Client sync:**
  1. Optimistic remove in `MessageNotifier.removeMessage`.
  2. Disk cache updated (`AppDataCache.messagesFile(groupId)`) so `loadMessages` / hydrate does not restore deleted rows.
  3. Socket `message_deleted` via global `MessageRealtimeBinder` → `onMessageDeleted` (pilgrim + moderator). Server emits to `group_{id}` and each `user_{memberId}`.

## Pilgrim delivery (socket + FCM)

- Moderator sends → server emits `new_message` to `group_{id}` and enqueues FCM per pilgrim (`Cloud Tasks` → `/internal/notify`).
- **Foreground pilgrim app:** tray FCM is suppressed; chat updates via socket `appendMessage`, with **FCM-triggered `loadMessages` fallback** if the socket was missed.
- **Background:** system notification from FCM; tap opens chat.
- GCP: look for `FCM Notification sent` and `[CloudTasks] Enqueued` in `mc-backend-prod1` logs; stale tokens log `Requested entity was not found`.

## Related files

| File | Role |
|------|------|
| `lib/features/moderator/screens/group_messages_screen.dart` | Broadcast UI, socket listener |
| `lib/features/shared/providers/message_provider.dart` | Load, send, delete, cache |
| `mc_backend_app/controllers/message_controller.js` | Delete + socket emit |
| `lib/features/moderator/screens/group_management_screen.dart` | Pilgrim row ⋮ menu (call, navigate, profile, chat) |
