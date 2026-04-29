import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/standard_snackbar.dart';
import '../providers/moderator_provider.dart';

class JoinGroupScreen extends ConsumerStatefulWidget {
  const JoinGroupScreen({super.key});

  @override
  ConsumerState<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends ConsumerState<JoinGroupScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  final TextEditingController _codeController = TextEditingController();
  bool _isManualEntry = false;
  bool _isLoading = false;
  bool _scanHandled = false;

  @override
  void dispose() {
    _scannerController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleJoin(String code) async {
    if (code.trim().isEmpty) return;
    
    setState(() {
      _isLoading = true;
    });

    final (success, error) = await ref.read(moderatorProvider.notifier).joinGroup(code);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (success) {
        StandardSnackBar.showSuccess(context, 'group_join_success'.tr());
        Navigator.of(context).pop();
      } else {
        StandardSnackBar.showError(context, error ?? 'group_join_failed'.tr());
        _scanHandled = false; // Allow re-scanning on error
        if (!_isManualEntry) {
           _scannerController.start();
        }
      }
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanHandled || _isLoading || _isManualEntry) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || code.trim().isEmpty) return;

    _scanHandled = true;
    _scannerController.stop();
    _handleJoin(code);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF0F0F8),
      appBar: AppBar(
        title: Text(
          'join_group'.tr(),
          style: TextStyle(
            fontFamily: 'Lexend',
            fontWeight: FontWeight.w700,
            fontSize: 18.sp,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Symbols.arrow_back, color: isDark ? Colors.white : AppColors.textDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!_isManualEntry) ...[
                    Text(
                      'scan_group_qr'.tr(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 14.sp,
                        color: isDark ? AppColors.textMutedLight : Colors.grey.shade600,
                      ),
                    ),
                    SizedBox(height: 24.h),
                    Container(
                      height: 300.h,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24.r),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22.r),
                        child: Stack(
                          children: [
                            MobileScanner(
                              controller: _scannerController,
                              onDetect: _onDetect,
                            ),
                            // Scanning overlay
                            _buildScannerOverlay(),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    SizedBox(height: 40.h),
                    Text(
                      'enter_group_code_manual'.tr(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 14.sp,
                        color: isDark ? AppColors.textMutedLight : Colors.grey.shade600,
                      ),
                    ),
                    SizedBox(height: 24.h),
                    TextField(
                      controller: _codeController,
                      textCapitalization: TextCapitalization.characters,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 24.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 4,
                        color: isDark ? Colors.white : AppColors.textDark,
                      ),
                      decoration: InputDecoration(
                        hintText: 'CODE123',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.white24 : Colors.grey.shade300,
                          letterSpacing: 4,
                        ),
                        filled: true,
                        fillColor: isDark ? AppColors.surfaceDark : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16.r),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(vertical: 20.h),
                      ),
                    ),
                    SizedBox(height: 32.h),
                    ElevatedButton(
                      onPressed: _isLoading ? null : () => _handleJoin(_codeController.text),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: Size(double.infinity, 56.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? SizedBox(
                              width: 24.w,
                              height: 24.w,
                              child: const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'join_group'.tr(),
                              style: TextStyle(
                                fontFamily: 'Lexend',
                                fontWeight: FontWeight.w700,
                                fontSize: 16.sp,
                              ),
                            ),
                    ),
                  ],
                  SizedBox(height: 40.h),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          _isManualEntry = !_isManualEntry;
                          _scanHandled = false;
                          if (!_isManualEntry) {
                            _scannerController.start();
                          } else {
                            _scannerController.stop();
                          }
                        });
                      },
                      child: Text(
                        _isManualEntry ? 'back_to_scan'.tr() : 'enter_code_instead'.tr(),
                        style: TextStyle(
                          fontFamily: 'Lexend',
                          fontWeight: FontWeight.w600,
                          fontSize: 14.sp,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerOverlay() {
    return Stack(
      children: [
        // Darkened areas
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(alpha: 0.5),
            BlendMode.srcOut,
          ),
          child: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  backgroundBlendMode: BlendMode.dstOut,
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: Container(
                  width: 200.w,
                  height: 200.w,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Corner indicators
        Align(
          alignment: Alignment.center,
          child: Container(
            width: 200.w,
            height: 200.w,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Stack(
              children: [
                _buildCorner(Alignment.topLeft),
                _buildCorner(Alignment.topRight),
                _buildCorner(Alignment.bottomLeft),
                _buildCorner(Alignment.bottomRight),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCorner(Alignment alignment) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 30.w,
        height: 30.w,
        decoration: BoxDecoration(
          border: Border(
            top: alignment == Alignment.topLeft || alignment == Alignment.topRight
                ? const BorderSide(color: AppColors.primary, width: 4)
                : BorderSide.none,
            bottom: alignment == Alignment.bottomLeft || alignment == Alignment.bottomRight
                ? const BorderSide(color: AppColors.primary, width: 4)
                : BorderSide.none,
            left: alignment == Alignment.topLeft || alignment == Alignment.bottomLeft
                ? const BorderSide(color: AppColors.primary, width: 4)
                : BorderSide.none,
            right: alignment == Alignment.topRight || alignment == Alignment.bottomRight
                ? const BorderSide(color: AppColors.primary, width: 4)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}
