import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/services/api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_logger.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/call_history_api.dart';
import '../providers/missed_calls_unread_provider.dart';

/// Lists recent voice calls from `GET /call-history` (moderator + pilgrim).
/// Set [missedOnly] to show only missed rows and to clear unread badge when opened.
class CallHistoryScreen extends ConsumerStatefulWidget {
  const CallHistoryScreen({super.key, this.missedOnly = false});

  final bool missedOnly;

  @override
  ConsumerState<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends ConsumerState<CallHistoryScreen> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final all = await CallHistoryApi.fetchCallHistory();
      final rows = widget.missedOnly
          ? all.where((c) => c['status']?.toString() == 'missed').toList()
          : all;
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
      if (widget.missedOnly) {
        try {
          await CallHistoryApi.markMissedCallsRead();
          await ref.read(missedCallsUnreadProvider.notifier).refresh();
        } catch (e) {
          AppLogger.w('[CallHistory] mark-read: $e');
        }
      }
    } on DioException catch (e) {
      AppLogger.e('[CallHistory] load failed: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ApiService.parseError(e);
      });
    } catch (e) {
      AppLogger.e('[CallHistory] load failed: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'call_history_load_error'.tr();
      });
    }
  }

  static String _idOf(dynamic ref) {
    if (ref is Map) {
      return (ref['_id'] ?? ref['id'] ?? '').toString();
    }
    return ref?.toString() ?? '';
  }

  static String _nameOf(dynamic ref) {
    if (ref is Map) {
      final n = ref['full_name']?.toString();
      if (n != null && n.isNotEmpty) return n;
    }
    return 'Unknown';
  }

  /// Pilgrim ↔ moderator: show Munawwara Care, not moderator personal name / id.
  String _peerDisplayName({
    required String myId,
    required String? myRole,
    required Map<String, dynamic> row,
    required bool outgoing,
    required dynamic otherRef,
  }) {
    if (myRole?.toLowerCase() != 'pilgrim') return _nameOf(otherRef);

    final callerRaw = row['caller_id'];
    final receiverRaw = row['receiver_id'];
    final callerIsMod = callerRaw is Map &&
        callerRaw['user_type']?.toString().toLowerCase() == 'moderator';
    final receiverIsMod = receiverRaw is Map &&
        receiverRaw['user_type']?.toString().toLowerCase() == 'moderator';

    if (!outgoing && callerIsMod) return 'call_support_display_name'.tr();
    if (outgoing && receiverIsMod) return 'call_support_display_name'.tr();

    return _nameOf(otherRef);
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'ringing':
        return 'call_history_status_ringing'.tr();
      case 'in-progress':
        return 'call_history_status_in_progress'.tr();
      case 'completed':
        return 'call_history_status_completed'.tr();
      case 'missed':
        return 'call_history_status_missed'.tr();
      case 'declined':
        return 'call_history_status_declined'.tr();
      case 'unreachable':
        return 'call_history_status_unreachable'.tr();
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final textPrimary = isDark ? AppColors.textLight : AppColors.textDark;
    final textMuted = isDark
        ? AppColors.textMutedLight
        : AppColors.textMutedDark;
    final auth = ref.watch(authProvider);
    final myId = auth.userId ?? '';
    final myRole = auth.role;
    final title = widget.missedOnly
        ? 'missed_calls_title'.tr()
        : 'call_history_title'.tr();

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(
          title,
          style: TextStyle(
            fontFamily: 'Lexend',
            fontWeight: FontWeight.w600,
            fontSize: 18.sp,
            color: textPrimary,
          ),
        ),
        backgroundColor: bg,
        foregroundColor: textPrimary,
        elevation: 0,
        actions: [
          if (widget.missedOnly)
            TextButton(
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute<void>(
                    builder: (_) => const CallHistoryScreen(),
                  ),
                );
              },
              child: Text(
                'missed_calls_see_all'.tr(),
                style: TextStyle(
                  fontFamily: 'Lexend',
                  fontWeight: FontWeight.w600,
                  fontSize: 13.sp,
                  color: AppColors.primary,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: EdgeInsets.all(24.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        color: textMuted,
                        fontSize: 15.sp,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    FilledButton(
                      onPressed: _load,
                      child: Text('call_history_retry'.tr()),
                    ),
                  ],
                ),
              ),
            )
          : _rows.isEmpty
          ? Center(
              child: Text(
                widget.missedOnly
                    ? 'missed_calls_empty'.tr()
                    : 'call_history_empty'.tr(),
                style: TextStyle(
                  fontFamily: 'Lexend',
                  color: textMuted,
                  fontSize: 16.sp,
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                itemCount: _rows.length,
                separatorBuilder: (_, unused) => SizedBox(height: 8.h),
                itemBuilder: (context, i) {
                  final c = _rows[i];
                  final callerId = _idOf(c['caller_id']);
                  final outgoing = callerId == myId;
                  final other = outgoing ? c['receiver_id'] : c['caller_id'];
                  final otherName = _peerDisplayName(
                    myId: myId,
                    myRole: myRole,
                    row: c,
                    outgoing: outgoing,
                    otherRef: other,
                  );
                  final status = c['status']?.toString() ?? '';
                  final created =
                      c['createdAt']?.toString() ?? c['created_at']?.toString();
                  DateTime? dt;
                  if (created != null && created.isNotEmpty) {
                    try {
                      dt = DateTime.parse(created).toLocal();
                    } catch (_) {}
                  }
                  final timeStr = dt != null
                      ? DateFormat.yMMMd().add_jm().format(dt)
                      : '';

                  return Material(
                    color: isDark ? AppColors.surfaceDark : Colors.white,
                    borderRadius: BorderRadius.circular(14.r),
                    child: ListTile(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 8.h,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primary.withValues(
                          alpha: 0.2,
                        ),
                        child: Icon(
                          outgoing ? Icons.call_made : Icons.call_received,
                          color: AppColors.primary,
                          size: 22.sp,
                        ),
                      ),
                      title: Text(
                        otherName,
                        style: TextStyle(
                          fontFamily: 'Lexend',
                          fontWeight: FontWeight.w600,
                          fontSize: 15.sp,
                          color: textPrimary,
                        ),
                      ),
                      subtitle: Padding(
                        padding: EdgeInsets.only(top: 4.h),
                        child: Text(
                          '${outgoing ? 'call_history_outgoing'.tr() : 'call_history_incoming'.tr()} · ${_statusLabel(status)}',
                          style: TextStyle(
                            fontFamily: 'Lexend',
                            fontSize: 12.sp,
                            color: textMuted,
                          ),
                        ),
                      ),
                      trailing: Text(
                        timeStr,
                        style: TextStyle(
                          fontFamily: 'Lexend',
                          fontSize: 11.sp,
                          color: textMuted,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
