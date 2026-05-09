import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/app_logger.dart';
import '../../../core/widgets/in_app_popup.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/message_model.dart';
import '../providers/message_provider.dart';
import 'chat_popup_dedup.dart';

class ChatNotificationHelper {
  static final AudioPlayer _sfxPlayer = AudioPlayer();

  static String _messageIdFromMap(Map<String, dynamic> map) {
    final raw = map['_id'] ?? map['id'];
    if (raw == null) return '';
    if (raw is String) return raw.trim();
    if (raw is Map) {
      final oid = raw[r'$oid'] ?? raw['oid'];
      if (oid != null) return oid.toString().trim();
    }
    return raw.toString().trim();
  }

  static Future<void> _recordDedup(
    SharedPreferences prefs,
    int msgMs,
    String messageId,
  ) async {
    await prefs.setInt(ChatPopupDedup.lastPopupMsKey, msgMs);
    if (messageId.isEmpty) return;
    final existing = prefs.getStringList(ChatPopupDedup.notifiedIdsKey) ?? [];
    if (existing.contains(messageId)) return;
    final next = [...existing, messageId];
    final trimmed = next.length > ChatPopupDedup.maxNotifiedIds
        ? next.sublist(next.length - ChatPopupDedup.maxNotifiedIds)
        : next;
    await prefs.setStringList(ChatPopupDedup.notifiedIdsKey, trimmed);
  }

  static Future<void> showIncomingMessage({
    required BuildContext context,
    required WidgetRef ref,
    required Map<String, dynamic> map,
    required VoidCallback onViewChat,
  }) async {
    if (!context.mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final messageId = _messageIdFromMap(map);
      final notifiedIds =
          prefs.getStringList(ChatPopupDedup.notifiedIdsKey) ?? [];
      if (messageId.isNotEmpty && notifiedIds.contains(messageId)) {
        AppLogger.d(
          '[ChatNotificationHelper] Skipping popup (id dedup) id=$messageId',
        );
        return;
      }

      final createdAtRaw = map['created_at']?.toString() ??
          map['createdAt']?.toString() ??
          map['timestamp']?.toString();
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      var msgMs = nowMs;
      if (createdAtRaw != null && createdAtRaw.isNotEmpty) {
        try {
          msgMs = DateTime.parse(createdAtRaw).toLocal().millisecondsSinceEpoch;
        } catch (_) {}
      }

      // Prevent replaying old socket messages on reconnect/hot restart.
      final lastMs = prefs.getInt(ChatPopupDedup.lastPopupMsKey) ?? 0;
      if (msgMs <= lastMs) {
        AppLogger.d(
          '[ChatNotificationHelper] Skipping popup (dedup) '
          'msgMs=$msgMs lastMs=$lastMs',
        );
        return;
      }

      final msg = GroupMessage.fromJson(map);

      // Don't show popup for our own messages
      final myId = ref.read(authProvider).userId;
      if (msg.sender?.id == myId) return;

      // ── Play SFX and Haptics ───────────────────────────────────────────────
      if (msg.isUrgent) {
        _sfxPlayer.play(AssetSource('static/urgent_tts.wav'));
        HapticFeedback.heavyImpact();
        // Vibrate twice for urgency
        HapticFeedback.vibrate();
      } else {
        _sfxPlayer.play(AssetSource('static/in_app.mp3'));
        HapticFeedback.lightImpact();
      }

      final senderName = msg.isFromModerator
          ? 'call_support_display_name'.tr()
          : (msg.sender?.fullName ?? 'notification_title'.tr());

      if (msg.type == 'meetpoint') {
        // Meetpoint message → special popup with Navigate button
        final mpName =
            msg.meetpointData?['name']?.toString() ?? 'meetpoint'.tr();
        final lat = msg.meetpointData?['latitude'];
        final lng = msg.meetpointData?['longitude'];
        final mTimeRaw = msg.meetpointData?['meetpoint_time'];
        String? displayTime;
        if (mTimeRaw != null) {
          try {
            final dt = DateTime.parse(mTimeRaw.toString());
            displayTime = DateFormat('hh:mm a').format(dt);
          } catch (_) {}
        }
        InAppPopup.showMeetpoint(
          context,
          name: mpName,
          body: msg.content,
          time: displayTime,
          onNavigate: (lat != null && lng != null)
              ? () {
                  final url = Uri.parse(
                    'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
                  );
                  launchUrl(url, mode: LaunchMode.externalApplication);
                }
              : null,
        );
      } else {
        // Only show popup for urgent messages or brief for non-urgent
        if (!msg.isUrgent) {
          // Non-urgent: brief auto-dismissing popup (no lock, no TTS)
          final body = msg.content ??
              (msg.type == 'voice'
                  ? '\ud83c\udfa4 ${'voice_message'.tr()}'
                  : '');
          InAppPopup.show(
            context,
            title: senderName,
            body: body,
            isUrgent: false,
            lockUntilDismiss: false,
            duration: const Duration(seconds: 4),
            onViewChat: onViewChat,
          );
          await _recordDedup(prefs, msgMs, msg.id);
          return;
        }

        final body = msg.content ??
            (msg.type == 'voice' ? '🎤 ${'voice_message'.tr()}' : '');

        String? playType;
        String? playValue;
        if (msg.isUrgent && msg.type == 'voice' && msg.mediaUrl != null) {
          playType = 'voice';
          playValue = ref
              .read(messageProvider.notifier)
              .buildUploadUrl(msg.mediaUrl!);
        } else if (msg.isUrgent && msg.type == 'tts') {
          playType = 'tts';
          playValue = msg.originalText ?? msg.content ?? '';
        }

        InAppPopup.show(
          context,
          title: senderName,
          body: body,
          isUrgent: msg.isUrgent,
          lockUntilDismiss: true,
          playType: playType,
          playValue: playValue,
          onViewChat: onViewChat,
        );
      }

      await _recordDedup(prefs, msgMs, msg.id);
    } catch (e) {
      AppLogger.e('[ChatNotificationHelper] Error showing popup: $e');
    }
  }

  static void dispose() {
    _sfxPlayer.dispose();
  }
}
