import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/router/app_router.dart';
import '../../../core/services/socket_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/widgets/standard_snackbar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../calling/calling_scope.dart';
import '../providers/moderator_provider.dart';
import '../widgets/pilgrim_profile_sheet.dart';
import '../widgets/sos_alert_dialog.dart';

/// Dedupes and shows one in-app SOS dialog per [sosId] (or per burst if id missing).
class SosAlertCoordinator {
  SosAlertCoordinator._();

  static String? _lastShownSosId;
  static DateTime? _lastShownAt;
  static const _dedupeWindow = Duration(seconds: 4);

  /// Set after IDE hot reload so a replayed socket/FCM SOS or reset dedupe
  /// state does not immediately show the full-screen moderator dialog again.
  static DateTime? _suppressDialogsUntil;

  /// Called from app `reassemble()` (debug/profile hot reload only).
  static void suppressInAppSosAlertsFor(Duration duration) {
    if (kReleaseMode) return;
    _suppressDialogsUntil = DateTime.now().add(duration);
    AppLogger.i(
      '[SosAlertCoordinator] In-app SOS dialogs suppressed for '
      '${duration.inSeconds}s (post hot-reload window)',
    );
  }

  /// Unified entry for socket payload, FCM `data`, or pending deep-link map.
  static Future<void> showOnceFromMap(Map<String, dynamic> raw) async {
    final until = _suppressDialogsUntil;
    if (until != null && DateTime.now().isBefore(until)) {
      AppLogger.i(
        '[SosAlertCoordinator] Skipped SOS dialog (post hot-reload quiet window)',
      );
      return;
    }

    final payload = _SosPayload.fromMap(raw);
    final sid = payload.sosId;
    if (sid != null && sid.isNotEmpty) {
      if (_lastShownSosId == sid &&
          _lastShownAt != null &&
          DateTime.now().difference(_lastShownAt!) < _dedupeWindow) {
        AppLogger.i('[SosAlertCoordinator] Deduped duplicate sos_id=$sid');
        return;
      }
      _lastShownSosId = sid;
      _lastShownAt = DateTime.now();
    } else {
      // No id: still avoid stacking identical dialogs within the window
      final composite =
          '${payload.pilgrimId ?? ""}|${payload.groupId ?? ""}|${payload.pilgrimName}';
      if (_lastShownSosId == composite &&
          _lastShownAt != null &&
          DateTime.now().difference(_lastShownAt!) < _dedupeWindow) {
        return;
      }
      _lastShownSosId = composite;
      _lastShownAt = DateTime.now();
    }

    final nav = AppRouter.navigatorKey.currentState;
    final ctx = AppRouter.navigatorKey.currentContext;
    if (nav == null || ctx == null || !ctx.mounted) {
      AppLogger.w('[SosAlertCoordinator] No navigator — caller should use pending SOS');
      return;
    }

    final groupLabel = payload.groupName.isEmpty ? '—' : payload.groupName;
    final locationLine = payload.hasCoords
        ? 'sos_mod_dialog_location_coords'.tr(
            namedArgs: {
              'lat': payload.lat!.toStringAsFixed(5),
              'lng': payload.lng!.toStringAsFixed(5),
            },
          )
        : 'sos_mod_dialog_location_unknown'.tr();

    await showDialog<void>(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return SosAlertDialog(
          pilgrimName: payload.pilgrimName,
          groupName: groupLabel,
          locationLine: locationLine,
          onLater: () => Navigator.of(dialogCtx).pop(),
          onReview: () {
            Navigator.of(dialogCtx).pop();
            unawaited(_openReviewFlow(payload));
          },
        );
      },
    );
  }

  static Future<void> _openReviewFlow(_SosPayload payload) async {
    final c = CallingScope.riverpod;
    if (c == null) {
      AppLogger.e('[SosAlertCoordinator] CallingScope.riverpod is null');
      return;
    }

    final gid = payload.groupId;
    final pid = payload.pilgrimId;
    if (gid != null && gid.isNotEmpty && pid != null && pid.isNotEmpty) {
      final handling = <String, dynamic>{
        'groupId': gid,
        'pilgrimId': pid,
      };
      final sid = payload.sosId;
      if (sid != null && sid.isNotEmpty) handling['sos_id'] = sid;
      SocketService.emit('sos_handling', handling);
    }

    await c.read(moderatorProvider.notifier).loadDashboard(silently: true);

    PilgrimInGroup? target;
    final groups = c.read(moderatorProvider).groups;
    if (gid != null && pid != null) {
      for (final g in groups) {
        if (g.id == gid) {
          try {
            target = g.pilgrims.firstWhere((p) => p.id == pid);
          } catch (_) {}
          break;
        }
      }
    }

    final sheetCtx = AppRouter.navigatorKey.currentContext;
    final currentUserId = c.read(authProvider).userId ?? '';

    if (sheetCtx != null &&
        sheetCtx.mounted &&
        target != null &&
        gid != null &&
        gid.isNotEmpty) {
      showPilgrimProfileSheet(
        sheetCtx,
        target,
        gid,
        currentUserId,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final snackCtx = AppRouter.navigatorKey.currentContext;
        if (snackCtx != null && snackCtx.mounted) {
          StandardSnackBar.showInfo(
            snackCtx,
            'sos_mod_sheet_call_hint'.tr(),
          );
        }
      });
    } else {
      final snackCtx = AppRouter.navigatorKey.currentContext;
      if (snackCtx != null && snackCtx.mounted) {
        StandardSnackBar.showInfo(
          snackCtx,
          'sos_mod_pilgrim_not_loaded'.tr(),
        );
      }
    }
  }
}

class _SosPayload {
  final String? sosId;
  final String pilgrimName;
  final String? pilgrimId;
  final String? groupId;
  final String groupName;
  final double? lat;
  final double? lng;

  _SosPayload({
    required this.sosId,
    required this.pilgrimName,
    required this.pilgrimId,
    required this.groupId,
    required this.groupName,
    required this.lat,
    required this.lng,
  });

  bool get hasCoords => lat != null && lng != null;

  static _SosPayload fromMap(Map<String, dynamic> raw) {
    String? socketStringId(dynamic v) {
      if (v == null) return null;
      if (v is String) return v;
      if (v is Map) {
        final id = v['_id'] ?? v['id'];
        return id?.toString();
      }
      return v.toString();
    }

    final name =
        raw['pilgrim_name']?.toString() ?? raw['pilgrimName']?.toString() ?? 'A pilgrim';
    final pid = socketStringId(raw['pilgrim_id']);
    final gid = socketStringId(raw['group_id']);
    final gname = raw['group_name']?.toString() ?? '';
    final sid = raw['sos_id']?.toString();

    double? lat;
    double? lng;
    final loc = raw['location'];
    if (loc is Map) {
      lat = _readCoord(loc['lat']) ?? _readCoord(loc['latitude']);
      lng = _readCoord(loc['lng']) ?? _readCoord(loc['longitude']);
    }
    lat ??= _readCoord(raw['lat']);
    lng ??= _readCoord(raw['lng']);

    return _SosPayload(
      sosId: sid,
      pilgrimName: name,
      pilgrimId: pid,
      groupId: gid,
      groupName: gname,
      lat: lat,
      lng: lng,
    );
  }

  static double? _readCoord(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}
