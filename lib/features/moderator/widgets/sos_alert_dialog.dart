import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';

/// In-app SOS alert for moderators (single surface; complements one FCM tray notification).
class SosAlertDialog extends StatelessWidget {
  final String pilgrimName;
  final String groupName;
  final String locationLine;
  final VoidCallback onReview;
  final VoidCallback onLater;

  const SosAlertDialog({
    super.key,
    required this.pilgrimName,
    required this.groupName,
    required this.locationLine,
    required this.onReview,
    required this.onLater,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : AppColors.textDark;
    final bodyColor = isDark ? Colors.white70 : AppColors.textDark;

    return AlertDialog(
      icon: Icon(
        Symbols.crisis_alert,
        color: AppColors.error,
        size: 40.w,
      ),
      title: Text(
        'sos_mod_dialog_title'.tr(),
        style: TextStyle(
          fontFamily: 'Lexend',
          fontWeight: FontWeight.w800,
          fontSize: 18.sp,
          color: titleColor,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'sos_mod_dialog_body_line1'.tr(
                namedArgs: {
                  'name': pilgrimName,
                  'group': groupName.isEmpty ? '—' : groupName,
                },
              ),
              style: TextStyle(
                fontFamily: 'Lexend',
                fontSize: 15.sp,
                height: 1.45,
                color: bodyColor,
              ),
            ),
            SizedBox(height: 12.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Symbols.location_on,
                  size: 18.w,
                  color: AppColors.info,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    locationLine,
                    style: TextStyle(
                      fontFamily: 'Lexend',
                      fontSize: 13.sp,
                      height: 1.4,
                      color: isDark ? Colors.white60 : AppColors.textMutedDark,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Text(
              'sos_mod_dialog_call_hint'.tr(),
              style: TextStyle(
                fontFamily: 'Lexend',
                fontSize: 12.sp,
                height: 1.35,
                color: isDark ? Colors.white54 : AppColors.textMutedLight,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: onLater,
          child: Text(
            'sos_mod_dialog_later'.tr(),
            style: const TextStyle(fontFamily: 'Lexend'),
          ),
        ),
        FilledButton(
          onPressed: onReview,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
          ),
          child: Text(
            'sos_mod_dialog_review'.tr(),
            style: const TextStyle(fontFamily: 'Lexend', fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
