import '../../core/services/api_service.dart';
import '../../core/services/socket_service.dart';
import '../../core/utils/app_logger.dart';

/// Socket + HTTP fallbacks for voice-call signaling (kept out of [CallNotifier]
/// so the notifier stays focused on state + Agora).
class CallSignaling {
  CallSignaling._();

  static void emitWhenConnected(String event, Map<String, dynamic> payload) {
    if (SocketService.isConnected) {
      SocketService.emit(event, payload);
      return;
    }

    AppLogger.w('[CallSignaling] Socket not connected, queueing "$event" emit');
    void sendOnce() {
      SocketService.emit(event, payload);
      SocketService.offConnected(sendOnce);
      AppLogger.i('[CallSignaling] Queued "$event" emit sent after reconnect');
    }

    SocketService.onConnected(sendOnce);
  }

  /// HTTP fallback when socket is not up (cold start / background).
  static void notifyAnswerHttp(String callerId, String? answererId) {
    ApiService.dio
        .post(
          '/call-history/answer',
          data: {'callerId': callerId, 'answererId': answererId ?? ''},
        )
        .then(
          (_) => AppLogger.i('[CallSignaling] HTTP call-answer → $callerId'),
        )
        .catchError(
          (e) => AppLogger.e('[CallSignaling] HTTP call-answer failed: $e'),
        );
  }

  static void notifyDeclineHttp(
    String callerId,
    String? declinerId, {
    bool noAnswer = false,
  }) {
    ApiService.dio
        .post(
          '/call-history/decline',
          data: {
            'callerId': callerId,
            'declinerId': declinerId ?? '',
            if (noAnswer) 'noAnswer': true,
          },
        )
        .then(
          (_) => AppLogger.i('[CallSignaling] HTTP call-decline → $callerId'),
        )
        .catchError(
          (e) => AppLogger.e('[CallSignaling] HTTP call-decline failed: $e'),
        );
  }
}
