import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/router/app_router.dart';
import '../../core/services/callkit_service.dart';
import '../../core/utils/app_logger.dart';
import 'calling_scope.dart';
import 'providers/call_provider.dart';
import 'screens/voice_call_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NativeCallCoordinator
//
// Owns everything that bridges Android/iOS CallKit ↔ Riverpod ↔ navigation.
// Keeps [main.dart] free of call-specific globals except assigning
// [CallingScope.riverpod].
// ─────────────────────────────────────────────────────────────────────────────

/// Whether a [VoiceCallScreen] push from native accept is in progress.
bool _navigatingToCall = false;

bool get isNavigatingToCall => _navigatingToCall;

Map<String, String>? _pendingAcceptedCall;

/// Queued native decline/timeout before Riverpod is ready ([consumePendingDeclined]).
class PendingDecline {
  const PendingDecline({required this.callerId, this.noAnswer = false});
  final String callerId;
  final bool noAnswer;
}

PendingDecline? _pendingDeclined;

Map<String, String>? consumePendingAcceptedCall() {
  final data = _pendingAcceptedCall;
  _pendingAcceptedCall = null;
  return data;
}

PendingDecline? consumePendingDeclined() {
  final p = _pendingDeclined;
  _pendingDeclined = null;
  return p;
}

abstract final class NativeCallCoordinator {
  /// Subscribe to CallKit **before** async Firebase init so cold-start accept
  /// events are not dropped.
  static void registerEarlyListeners() {
    FlutterCallkitIncoming.onEvent.listen((CallEvent? event) async {
      if (event == null) return;
      AppLogger.i('📞 CallKit event: ${event.event}');

      final eventName = event.event.toString().toLowerCase();
      if (eventName.contains('start') && eventName.contains('call')) {
        AppLogger.i('✅ Call START event treated as ACCEPT');
        await _handleAcceptedCallEvent(event);
        return;
      }

      switch (event.event) {
        case Event.actionCallAccept:
          await _handleAcceptedCallEvent(event);
          break;

        case Event.actionCallDecline:
          AppLogger.w('❌ Call DECLINED from native call screen');
          final declineCallerId = await _resolveCallerIdFromEvent(event);
          _pendingAcceptedCall = null;
          final c = CallingScope.riverpod;
          if (c != null) {
            final currentState = c.read(callProvider);
            if (currentState.status == CallStatus.ringing) {
              c.read(callProvider.notifier).declineCall();
            } else if (declineCallerId.isNotEmpty) {
              AppLogger.w(
                '❌ Decline via HTTP fallback (cold-start, state=${currentState.status})',
              );
              c
                  .read(callProvider.notifier)
                  .declineCallFromCallerId(declineCallerId);
            }
          } else if (declineCallerId.isNotEmpty) {
            _pendingDeclined = PendingDecline(callerId: declineCallerId);
            AppLogger.w(
              '❌ Decline queued (container not ready) for callerId=$declineCallerId',
            );
            await _sendBackgroundDecline(declineCallerId, noAnswer: false);
            await CallKitService.instance.endCurrentCall();
          }
          break;

        case Event.actionCallTimeout:
          AppLogger.w('⏰ Call TIMEOUT from native call screen');
          final timeoutCallerId = await _resolveCallerIdFromEvent(event);
          _pendingAcceptedCall = null;
          final c = CallingScope.riverpod;
          if (c != null) {
            final currentState = c.read(callProvider);
            if (currentState.status == CallStatus.ringing) {
              c.read(callProvider.notifier).declineCallAsNoAnswer();
            } else if (timeoutCallerId.isNotEmpty) {
              AppLogger.w(
                '⏰ Timeout via HTTP fallback (cold-start, state=${currentState.status})',
              );
              c
                  .read(callProvider.notifier)
                  .declineCallFromCallerId(timeoutCallerId, noAnswer: true);
            }
          } else if (timeoutCallerId.isNotEmpty) {
            _pendingDeclined =
                PendingDecline(callerId: timeoutCallerId, noAnswer: true);
            AppLogger.w(
              '⏰ Timeout decline queued (container not ready) for callerId=$timeoutCallerId',
            );
            await _sendBackgroundDecline(timeoutCallerId, noAnswer: true);
            await CallKitService.instance.endCurrentCall();
          }
          break;

        case Event.actionCallEnded:
          AppLogger.i('📵 Call ENDED from native call screen');
          final endedCallerId = await _resolveCallerIdFromEvent(event);
          final c = CallingScope.riverpod;
          if (endedCallerId.isNotEmpty && c != null) {
            final currentState = c.read(callProvider);
            if (currentState.status == CallStatus.ringing) {
              c.read(callProvider.notifier).declineCall();
            }
          } else if (endedCallerId.isNotEmpty && c == null) {
            if (_pendingAcceptedCall == null) {
              _pendingDeclined = PendingDecline(callerId: endedCallerId);
              AppLogger.w(
                '📵 Ended mapped to queued decline (container not ready) for callerId=$endedCallerId',
              );
              await _sendBackgroundDecline(endedCallerId, noAnswer: false);
            }
            await CallKitService.instance.endCurrentCall();
          }
          _pendingAcceptedCall = null;
          await CallKitService.instance.clearLocalCallTracking();
          break;

        default:
          break;
      }
    });
  }

  /// If user accepted from native UI before Flutter ran, restore pending join.
  static Future<void> recoverAcceptedCallOnStartup() async {
    try {
      final activeCalls = await FlutterCallkitIncoming.activeCalls();
      if (activeCalls is List && activeCalls.isNotEmpty) {
        final pending = await CallKitService.readRecentPendingIncomingCall(
          maxAgeSeconds: 90,
        );
        if (pending != null && (pending['channelName'] ?? '').isNotEmpty) {
          _pendingAcceptedCall = {
            'callerId': pending['callerId'] ?? '',
            'callerName': (pending['callerName'] ?? '').isNotEmpty
                ? (pending['callerName'] ?? 'Unknown')
                : 'Unknown',
            'channelName': pending['channelName'] ?? '',
            'callerRole': pending['callerRole'] ?? '',
          };
          AppLogger.i(
            '📞 Startup recovery: restored pending accepted call from persisted CallKit payload',
          );
        }
      } else {
        await CallKitService.readRecentPendingIncomingCall(maxAgeSeconds: 90);
      }
    } catch (e) {
      AppLogger.e('📞 Startup recovery failed: $e');
    }
  }

  /// FCM foreground: `call_declined` / `call_cancel` from backend.
  static void handleForegroundCallControl(Map<String, dynamic> data) {
    final dataType = CallKitService.fcmCallControlType(data);
    if (dataType == null) return;

    AppLogger.w('📵 FCM call_declined/call_cancel — stopping call');
    final endReason = dataType == 'call_cancel' ? 'cancelled' : 'declined';
    final c = CallingScope.riverpod;
    if (c != null) {
      final cs = c.read(callProvider);
      if (cs.status == CallStatus.calling || cs.status == CallStatus.ringing) {
        c.read(callProvider.notifier).stopLocalCallSession(endReason: endReason);
        return;
      }
    }

    unawaited(CallKitService.persistPendingOutgoingStop(endReason));
    unawaited(CallKitService.instance.endCurrentCall());
  }
}

Future<void> _handleAcceptedCallEvent(CallEvent event) async {
  AppLogger.i('✅ Call ACCEPTED from native call screen');

  String channelName = _extractCallEventValue(event, 'channelName');
  String callerId = _extractCallEventValue(event, 'callerId');
  String callerName = _extractCallEventValue(event, 'callerName');
  String callerRole = _extractCallEventValue(event, 'callerRole');

  if (channelName.isEmpty || callerId.isEmpty) {
    final pending = await CallKitService.readRecentPendingIncomingCall(
      maxAgeSeconds: 90,
    );
    if (pending != null) {
      channelName = channelName.isNotEmpty
          ? channelName
          : (pending['channelName'] ?? '');
      callerId = callerId.isNotEmpty ? callerId : (pending['callerId'] ?? '');
      callerName = callerName.isNotEmpty
          ? callerName
          : (pending['callerName'] ?? '');
      callerRole = callerRole.isNotEmpty
          ? callerRole
          : (pending['callerRole'] ?? '');
      AppLogger.i('📞 Accept payload recovered from persisted pending call');
    }
  }

  _pendingAcceptedCall = {
    'callerId': callerId,
    'callerName': callerName.isNotEmpty ? callerName : 'Unknown',
    'channelName': channelName,
    'callerRole': callerRole,
  };

  AppLogger.i(
    '📞 Accept parsed: callerId=$callerId, channel=$channelName, name=$callerName',
  );

  final c = CallingScope.riverpod;
  if (c != null && channelName.isNotEmpty) {
    final notifier = c.read(callProvider.notifier);
    final currentState = c.read(callProvider);

    if (currentState.status == CallStatus.ringing) {
      _navigatingToCall = true;
      notifier.acceptCall();
      _navigateToVoiceCallScreen();
    } else if (!currentState.isInCall) {
      _navigatingToCall = true;
      notifier.acceptCallFromFcm(
        callerId: callerId,
        callerName: callerName.isNotEmpty ? callerName : 'Unknown',
        channelName: channelName,
      );
      _navigateToVoiceCallScreen();
    }
  }
}

Future<String> _resolveCallerIdFromEvent(CallEvent event) async {
  final fromEvent = _extractCallEventValue(event, 'callerId');
  if (fromEvent.isNotEmpty) return fromEvent;

  final pending = await CallKitService.readRecentPendingIncomingCall(
    maxAgeSeconds: 120,
  );
  return pending?['callerId'] ?? '';
}

String _extractCallEventValue(CallEvent event, String key) {
  final body = event.body;
  if (body is! Map) return '';

  dynamic value = body[key];

  if (value == null) {
    final extra = body['extra'];
    if (extra is Map) value = extra[key];
  }

  if (value == null) {
    final nestedBody = body['body'];
    if (nestedBody is Map) {
      value = nestedBody[key];
      if (value == null) {
        final nestedExtra = nestedBody['extra'];
        if (nestedExtra is Map) value = nestedExtra[key];
      }
    }
  }

  if (value == null) {
    final data = body['data'];
    if (data is Map) {
      value = data[key];
      if (value == null) {
        final dataExtra = data['extra'];
        if (dataExtra is Map) value = dataExtra[key];
      }
    }
  }

  return value?.toString() ?? '';
}

void _navigateToVoiceCallScreen() {
  _tryPushVoiceCall(attemptsLeft: 15);
}

void _tryPushVoiceCall({required int attemptsLeft}) {
  if (attemptsLeft <= 0) {
    _navigatingToCall = false;
    AppLogger.w(
      '📞 All navigation retries exhausted — relying on dashboard fallback',
    );
    return;
  }
  final nav = AppRouter.navigatorKey.currentState;
  if (nav != null) {
    if (VoiceCallScreen.isActive) {
      _navigatingToCall = false;
      AppLogger.d('📞 VoiceCallScreen already active — skipping push');
      return;
    }
    nav
        .push(MaterialPageRoute(builder: (_) => const VoiceCallScreen()))
        .then((_) => _navigatingToCall = false);
    AppLogger.i(
      '📞 Navigated to VoiceCallScreen (attempt ${16 - attemptsLeft})',
    );
  } else {
    Future.delayed(const Duration(milliseconds: 400), () {
      _tryPushVoiceCall(attemptsLeft: attemptsLeft - 1);
    });
  }
}

Future<void> _sendBackgroundDecline(
  String callerId, {
  bool noAnswer = false,
}) async {
  if (callerId.isEmpty) return;
  const fallbackUrl =
      'https://mcbackendapp-199324116788.europe-west8.run.app/api';
  try {
    String baseUrl = fallbackUrl;
    String declinerId = '';
    String callRecordId = '';
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('api_base_url');
      if (cached != null && cached.isNotEmpty) baseUrl = cached;
      declinerId = prefs.getString('user_id') ?? '';
      callRecordId = prefs.getString('pending_call_record_id') ?? '';
    } catch (_) {}

    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    await dio.post('/call-history/decline', data: {
      'callerId': callerId,
      if (declinerId.isNotEmpty) 'declinerId': declinerId,
      if (callRecordId.isNotEmpty) 'callRecordId': callRecordId,
      if (noAnswer) 'noAnswer': true,
    });
    AppLogger.i('❌ Background HTTP decline sent to $callerId (url=$baseUrl)');
  } catch (e) {
    AppLogger.e('Failed to send background decline: $e');
  }
}
