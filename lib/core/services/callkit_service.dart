import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../utils/app_logger.dart';

/// Shown on CallKit / prefs when a pilgrim receives a moderator call (native asset path).
const String kCallKitSupportAvatarAsset = 'assets/static/app_icon.png';

// ─────────────────────────────────────────────────────────────────────────────
// CallKitService — Shows native incoming call screen (like WhatsApp)
// Uses Android ConnectionService / iOS CallKit under the hood.
// Works even when app is killed, screen off, or locked.
// ─────────────────────────────────────────────────────────────────────────────

class CallKitService {
  static final CallKitService instance = CallKitService._();
  CallKitService._();

  static const _uuid = Uuid();
  static const _pendingCallerIdKey = 'pending_call_caller_id';
  static const _pendingCallerNameKey = 'pending_call_caller_name';
  static const _pendingCallerRoleKey = 'pending_call_caller_role';
  static const _pendingChannelNameKey = 'pending_call_channel_name';
  static const _pendingCreatedAtMsKey = 'pending_call_created_at_ms';
  static const _pendingCallUuidKey = 'pending_call_uuid';
  static const _prefsUserRoleKey = 'user_role';

  // Track the current call UUID so we can end it later
  String? _currentCallId;
  String? get currentCallId => _currentCallId;

  /// Native CallKit / Android notification id (matches [SharedPreferences] when
  /// Dart-side [_currentCallId] was cleared after tray hide).
  Future<String?> peekCallKitNotificationId() async {
    if (_currentCallId != null && _currentCallId!.isNotEmpty) return _currentCallId;
    final prefs = await SharedPreferences.getInstance();
    final fromPrefs = prefs.getString(_pendingCallUuidKey);
    if (fromPrefs != null && fromPrefs.isNotEmpty) return fromPrefs;
    return null;
  }

  /// Timestamp of the last showIncomingCall invocation — used to reject
  /// rapid duplicate invocations that slip past the _currentCallId guard.
  DateTime? _lastShowTime;

  /// Show a native incoming call screen.
  /// Call this from both foreground and background FCM handlers.
  Future<void> showIncomingCall({
    required String callerId,
    required String callerName,
    required String channelName,
    String? callerRole,
  }) async {
    // ── Guard 1: Dart-side flag (with stale-state recovery) ─────────────
    if (_currentCallId != null) {
      try {
        final activeCalls = await FlutterCallkitIncoming.activeCalls();
        final hasActiveNativeCall =
            activeCalls is List && activeCalls.isNotEmpty;
        if (!hasActiveNativeCall) {
          AppLogger.w(
            '📞 [CallKit] Stale _currentCallId detected with no active native call — resetting local tracking',
          );
          await clearLocalCallTracking();
        } else {
          AppLogger.w(
            '📞 [CallKit] _currentCallId already set and native call active — ignoring duplicate',
          );
          return;
        }
      } catch (e) {
        AppLogger.e('📞 [CallKit] stale-check activeCalls() failed: $e');
        return;
      }
    }

    // ── Guard 2: Timestamp-based dedup (5 s window) ─────────────────────
    final now = DateTime.now();
    if (_lastShowTime != null && now.difference(_lastShowTime!).inSeconds < 5) {
      AppLogger.w('📞 [CallKit] showIncomingCall called within 5 s — ignoring');
      return;
    }

    // ── Guard 3: Check actual system state for active calls ─────────────
    try {
      final activeCalls = await FlutterCallkitIncoming.activeCalls();
      if (activeCalls is List && activeCalls.isNotEmpty) {
        AppLogger.w(
          '📞 [CallKit] System reports ${activeCalls.length} active call(s) — ending stale calls first',
        );
        await FlutterCallkitIncoming.endAllCalls();
        // Small delay so the system UI fully dismisses
        await Future.delayed(const Duration(milliseconds: 300));
      }
    } catch (e) {
      AppLogger.e('📞 [CallKit] activeCalls() check failed: $e');
    }

    _currentCallId = _uuid.v4();
    _lastShowTime = now;

    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString(_prefsUserRoleKey) ?? '';
    final useSupportBranding = role == 'pilgrim';
    final nativeCallerLine = useSupportBranding
        ? _supportDisplayName()
        : callerName;
    final avatarAsset = useSupportBranding ? kCallKitSupportAvatarAsset : null;

    await _savePendingIncomingCall(
      callerId: callerId,
      callerName: nativeCallerLine,
      callerRole: callerRole ?? '',
      channelName: channelName,
    );

    final androidParams = AndroidParams(
      isCustomNotification: false,
      // Keep only [avatar] in the large ring; isShowLogo + logoUrl duplicates the same asset uptop.
      isShowLogo: false,
      logoUrl: null,
      ringtonePath: 'system_ringtone_default',
      backgroundColor: '#0B1220',
      actionColor: '#F97316',
      textColor: '#FFFFFF',
      isShowFullLockedScreen: true,
      incomingCallNotificationChannelName: 'Incoming Calls',
      isShowCallID: true,
    );

    final params = CallKitParams(
      id: _currentCallId!,
      nameCaller: nativeCallerLine,
      appName: 'Munawwara Care',
      avatar: avatarAsset,
      handle: callerRole ?? 'Voice Call',
      type: 0, // 0 = audio call, 1 = video call
      duration: 30000, // Ring for 30 seconds max
      textAccept: 'Accept',
      textDecline: 'Decline',
      missedCallNotification: const NotificationParams(
        showNotification: false, // backend sends the single missed-call FCM
        isShowCallback: false,
        subtitle: 'Missed Call',
        callbackText: 'Call Back',
      ),
      extra: <String, dynamic>{
        'callerId': callerId,
        'callerName': nativeCallerLine,
        'peerCallerName': callerName,
        'callerRole': callerRole ?? '',
        'channelName': channelName,
      },
      headers: <String, dynamic>{},
      android: androidParams,
      ios: const IOSParams(
        iconName: 'AppIcon',
        supportsVideo: false,
        maximumCallsPerCallGroup: 1,
        audioSessionMode: 'default',
        audioSessionActive: true,
        audioSessionPreferredSampleRate: 44100.0,
        audioSessionPreferredIOBufferDuration: 0.005,
        ringtonePath: 'system_ringtone_default',
      ),
    );

    await FlutterCallkitIncoming.showCallkitIncoming(params);
    AppLogger.i('📞 Native incoming call screen shown ($nativeCallerLine)');
  }

  static String _supportDisplayName() {
    try {
      return 'call_support_display_name'.tr();
    } catch (_) {
      return 'Munawwara Care';
    }
  }

  /// Android: `endCall` alone does not remove the incoming-call tray notification;
  /// the plugin expects [FlutterCallkitIncoming.hideCallkitIncoming] to run
  /// [clearIncomingNotification] (see Kotlin `hideCallkitIncoming`).
  static Future<void> _hideIncomingTrayForId(String id) async {
    if (id.isEmpty) return;
    try {
      await FlutterCallkitIncoming.hideCallkitIncoming(
        CallKitParams(
          id: id,
          nameCaller: '',
          appName: 'Munawwara Care',
          handle: '',
          type: 0,
        ),
      );
    } catch (e) {
      AppLogger.w('📞 [CallKit] hideCallkitIncoming failed: $e');
    }
  }

  /// Hides the Android incoming notification only — keeps SharedPreferences so
  /// a cold-start accept can still read `channelName` / caller from prefs.
  static Future<void> hideIncomingTrayFromPersistedUuidOnly() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uuid = prefs.getString(_pendingCallUuidKey);
      if (uuid != null && uuid.isNotEmpty) {
        await _hideIncomingTrayForId(uuid);
      }
    } catch (e) {
      AppLogger.w('📞 hideIncomingTrayFromPersistedUuidOnly: $e');
    }
  }

  Future<String?> _resolveActiveCallId() async {
    if (_currentCallId != null && _currentCallId!.isNotEmpty) {
      return _currentCallId;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final fromPrefs = prefs.getString(_pendingCallUuidKey);
      if (fromPrefs != null && fromPrefs.isNotEmpty) return fromPrefs;
    } catch (_) {}
    return null;
  }

  /// Hides the Android incoming notification after the user **accepts** (we do
  /// not send [endCall] here — that is for decline/teardown).
  ///
  /// Does **not** clear SharedPreferences: the persisted CallKit UUID must stay
  /// until [endCurrentCall] runs when the conversation ends (local hang-up or
  /// remote `call-end`). Otherwise Android keeps a stale "incoming/upcoming"
  /// notification because [hideCallkitIncoming] cannot be matched to an id.
  Future<void> dismissIncomingCallNotification() async {
    final id = await _resolveActiveCallId();
    if (id != null && id.isNotEmpty) {
      await _hideIncomingTrayForId(id);
    }
    _currentCallId = null;
    _lastShowTime = null;
  }

  /// End/dismiss the current incoming call UI.
  Future<void> endCurrentCall() async {
    final id = await _resolveActiveCallId();
    if (id != null && id.isNotEmpty) {
      await _hideIncomingTrayForId(id);
      try {
        await FlutterCallkitIncoming.endCall(id);
      } catch (e) {
        AppLogger.w('📞 [CallKit] endCall failed: $e');
      }
    }
    try {
      await FlutterCallkitIncoming.endAllCalls();
    } catch (e) {
      AppLogger.w('📞 [CallKit] endAllCalls failed: $e');
    }
    _currentCallId = null;
    _lastShowTime = null;
    await clearPendingIncomingCall();
  }

  /// End all calls (cleanup).
  Future<void> endAllCalls() async {
    try {
      final raw = await FlutterCallkitIncoming.activeCalls();
      if (raw is List) {
        for (final item in raw) {
          if (item is Map) {
            final cid = item['id']?.toString();
            if (cid != null && cid.isNotEmpty) {
              await _hideIncomingTrayForId(cid);
            }
          }
        }
      }
    } catch (e) {
      AppLogger.w('📞 [CallKit] activeCalls before endAllCalls: $e');
    }
    await FlutterCallkitIncoming.endAllCalls();
    _currentCallId = null;
    _lastShowTime = null;
    await clearPendingIncomingCall();
  }

  /// Clear Dart-side call tracking without touching native call UI.
  /// Useful when we receive terminal CallKit events and only need to reset
  /// local dedup/guard state.
  Future<void> clearLocalCallTracking() async {
    _currentCallId = null;
    _lastShowTime = null;
    await clearPendingIncomingCall();
  }

  static Future<void> _savePendingIncomingCall({
    required String callerId,
    required String callerName,
    required String callerRole,
    required String channelName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingCallerIdKey, callerId);
    await prefs.setString(_pendingCallerNameKey, callerName);
    await prefs.setString(_pendingCallerRoleKey, callerRole);
    await prefs.setString(_pendingChannelNameKey, channelName);
    await prefs.setInt(
      _pendingCreatedAtMsKey,
      DateTime.now().millisecondsSinceEpoch,
    );
    // Persist the CallKit UUID so a different background isolate can dismiss
    // this exact call (needed for call_cancel from killed state).
    final uuid = CallKitService.instance._currentCallId;
    if (uuid != null && uuid.isNotEmpty) {
      await prefs.setString(_pendingCallUuidKey, uuid);
    }
  }

  static Future<Map<String, String>?> readPendingIncomingCall() async {
    final prefs = await SharedPreferences.getInstance();
    final callerId = prefs.getString(_pendingCallerIdKey) ?? '';
    final callerName = prefs.getString(_pendingCallerNameKey) ?? '';
    final callerRole = prefs.getString(_pendingCallerRoleKey) ?? '';
    final channelName = prefs.getString(_pendingChannelNameKey) ?? '';

    if (callerId.isEmpty && channelName.isEmpty) return null;

    return {
      'callerId': callerId,
      'callerName': callerName,
      'callerRole': callerRole,
      'channelName': channelName,
      'createdAtMs': (prefs.getInt(_pendingCreatedAtMsKey) ?? 0).toString(),
    };
  }

  static Future<Map<String, String>?> readRecentPendingIncomingCall({
    int maxAgeSeconds = 90,
  }) async {
    final pending = await readPendingIncomingCall();
    if (pending == null) return null;

    final createdAtMs = int.tryParse(pending['createdAtMs'] ?? '0') ?? 0;
    if (createdAtMs <= 0) return pending;

    final ageMs = DateTime.now().millisecondsSinceEpoch - createdAtMs;
    if (ageMs > maxAgeSeconds * 1000) {
      await clearPendingIncomingCall();
      return null;
    }
    return pending;
  }

  static Future<void> clearPendingIncomingCall() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingCallerIdKey);
    await prefs.remove(_pendingCallerNameKey);
    await prefs.remove(_pendingCallerRoleKey);
    await prefs.remove(_pendingChannelNameKey);
    await prefs.remove(_pendingCreatedAtMsKey);
    await prefs.remove(_pendingCallUuidKey);
  }

  /// Process an FCM message and show incoming call if it's a call notification.
  /// Returns true if it was a call message and was handled.
  static Future<bool> handleFcmMessage(RemoteMessage message) async {
    final data = message.data;
    final type = data['type'];

    if (type == 'call_cancel') {
      AppLogger.i('📞 FCM call_cancel detected — dismissing native call UI');
      try {
        await CallKitService.instance.endCurrentCall();
      } catch (e) {
        AppLogger.e('📞 call_cancel endCurrentCall failed: $e');
      }
      try {
        await Future.delayed(const Duration(milliseconds: 500));
        await FlutterCallkitIncoming.endAllCalls();
      } catch (_) {}
      return true;
    }

    if (type != 'incoming_call') return false;

    final callerId = data['callerId'] ?? '';
    final callerName = data['callerName'] ?? data['title'] ?? 'Unknown';
    final callerRole = data['callerRole'] ?? '';
    final channelName = data['channelName'] ?? '';

    AppLogger.i('📞 FCM incoming_call detected — showing native call screen');
    AppLogger.i('   Caller: $callerName ($callerId)');
    AppLogger.i('   Channel: $channelName');

    await CallKitService.instance.showIncomingCall(
      callerId: callerId,
      callerName: callerName,
      channelName: channelName,
      callerRole: callerRole,
    );

    return true;
  }
}
