import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../call_navigation.dart';
import '../providers/call_provider.dart';
import '../screens/voice_call_screen.dart';
import 'call_peer_display.dart';

/// Persistent bar to return to an active call after leaving [VoiceCallScreen].
class ActiveCallBanner extends ConsumerWidget {
  const ActiveCallBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final call = ref.watch(callProvider);
    if (!call.isInCall || VoiceCallScreen.isActive) {
      return const SizedBox.shrink();
    }

    final peerName = resolveCallPeerDisplayName(call: call);
    final statusText = _subtitleForCall(call);
    final detailParts = <String>[];
    if (peerName.isNotEmpty) {
      detailParts.add(peerName);
    }
    if (statusText.isNotEmpty) {
      detailParts.add(statusText);
    }
    final detailLine = detailParts.join(' · ');

    return Positioned(
      left: 12.w,
      right: 12.w,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Semantics(
          button: true,
          label: 'active_call_return'.tr(),
          child: Material(
            color: AppColors.primary,
            elevation: 6,
            borderRadius: BorderRadius.circular(12.r),
            child: InkWell(
              onTap: () => openVoiceCallScreen(),
              borderRadius: BorderRadius.circular(12.r),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 14.w,
                  vertical: 10.h,
                ),
                child: Row(
                  children: [
                    Icon(
                      Symbols.call,
                      color: Colors.white,
                      size: 22.sp,
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'active_call_return'.tr(),
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14.sp,
                            ),
                          ),
                          if (detailLine.isNotEmpty)
                            Text(
                              detailLine,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 12.sp,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Icon(
                      Symbols.chevron_right,
                      color: Colors.white,
                      size: 22.sp,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _subtitleForCall(CallState call) {
    switch (call.status) {
      case CallStatus.connected:
        return call.formattedDuration;
      case CallStatus.calling:
        return 'active_call_calling'.tr();
      case CallStatus.ringing:
        return 'active_call_ringing'.tr();
      case CallStatus.connecting:
        return 'call_connecting'.tr();
      case CallStatus.idle:
      case CallStatus.ended:
        return '';
    }
  }
}
