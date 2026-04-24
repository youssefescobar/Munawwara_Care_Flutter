import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import '../theme/app_colors.dart';

class StandardDialog {
  StandardDialog._();

  /// Shows a standardized confirmation/alert dialog.
  /// [isDestructive] if true, the confirm button will be red.
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required String content,
    String? confirmText,
    String? cancelText,
    bool isDestructive = false,
    Widget? icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showDialog<T>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: icon,
        title: Text(title.tr()),
        content: Text(
          content.tr(),
          textAlign: TextAlign.center,
        ),
        actionsPadding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.h),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: Text(
                    (cancelText ?? 'dialog_cancel').tr(),
                    style: TextStyle(
                      fontFamily: 'Lexend',
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMutedLight,
                      fontSize: 14.sp,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true as T),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDestructive
                        ? Colors.red.shade600
                        : AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: Text(
                    (confirmText ?? 'dialog_confirm').tr(),
                    style: TextStyle(
                      fontFamily: 'Lexend',
                      fontWeight: FontWeight.w700,
                      fontSize: 14.sp,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Shows a standardized loading dialog.
  static void showLoading(BuildContext context, {String? message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Padding(
          padding: EdgeInsets.symmetric(vertical: 20.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              if (message != null) ...[
                SizedBox(height: 20.h),
                Text(
                  message.tr(),
                  style: TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
