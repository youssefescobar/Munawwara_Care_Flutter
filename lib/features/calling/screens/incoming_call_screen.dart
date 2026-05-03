import 'dart:ui' show FilterQuality, ImageFilter;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/services/callkit_service.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/call_provider.dart';
import 'voice_call_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// IncomingCallScreen — full-screen in-app incoming call (when not using tray only)
// Visual language matches [VoiceCallScreen] and app tokens.
// ─────────────────────────────────────────────────────────────────────────────

class IncomingCallScreen extends ConsumerStatefulWidget {
  const IncomingCallScreen({super.key});

  @override
  ConsumerState<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends ConsumerState<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final call = ref.watch(callProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = _IncomingPalette(isDark);

    ref.listen(callProvider, (_, next) {
      if ((next.status == CallStatus.idle || next.status == CallStatus.ended) &&
          mounted) {
        Navigator.of(context).maybePop();
      }
    });

    final name = call.incomingDisplayName ?? call.remoteUserName ?? 'Unknown';
    final initials = name
        .trim()
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: c.backgroundGradient),
        child: Stack(
          children: [
            Positioned(
              top: -60.h,
              left: -30.w,
              child: _SoftOrb(color: AppColors.primary.withValues(alpha: isDark ? 0.14 : 0.2), size: 200),
            ),
            Positioned(
              bottom: 120.h,
              right: -40.w,
              child: _SoftOrb(color: AppColors.accentGold.withValues(alpha: 0.08), size: 160),
            ),
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 28.h),
                  Center(
                    child: Text(
                      'call_incoming'.tr(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: c.textMuted,
                        fontSize: 12.sp,
                        fontFamily: 'Lexend',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(flex: 2),
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (_, child) {
                      final t = _pulseController.value;
                      final scale = 1.0 + 0.04 * t;
                      return Transform.scale(scale: scale, child: child);
                    },
                    child: call.displayPeerAsSupportBranding
                        ? _IncomingSupportBrandingAvatar(palette: c)
                        : _IncomingAvatarRing(initials: initials, palette: c),
                  ),
                  SizedBox(height: 22.h),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26.sp,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Lexend',
                      color: c.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'call_voice'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontFamily: 'Lexend',
                      color: c.textSecondary,
                    ),
                  ),
                  const Spacer(flex: 2),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32.w),
                    child: _SpeakerRow(call: call, palette: c, ref: ref),
                  ),
                  SizedBox(height: 28.h),
                  Container(
                    margin: EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.h),
                    padding: EdgeInsets.fromLTRB(20.w, 22.h, 20.w, 24.h),
                    decoration: BoxDecoration(
                      color: c.panelFill,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
                      border: Border.all(color: c.panelBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                          blurRadius: 24,
                          offset: const Offset(0, -6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _IncomingAction(
                          icon: Symbols.call_end,
                          label: 'call_decline'.tr(),
                          variant: _IncomingActionVariant.decline,
                          onTap: () => ref.read(callProvider.notifier).declineCall(),
                        ),
                        _IncomingAction(
                          icon: Symbols.call,
                          label: 'call_accept'.tr(),
                          variant: _IncomingActionVariant.accept,
                          onTap: () async {
                            await ref.read(callProvider.notifier).acceptCall();
                            if (context.mounted) {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) => const VoiceCallScreen(),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IncomingPalette {
  _IncomingPalette(bool isDark)
      : textPrimary = isDark ? AppColors.textLight : AppColors.textDark,
        textSecondary = isDark ? AppColors.textMutedLight : AppColors.textMutedDark,
        textMuted = isDark ? AppColors.textMutedLight.withValues(alpha: 0.8) : AppColors.textMutedDark,
        panelFill = isDark ? AppColors.surfaceDark : Colors.white,
        panelBorder = isDark ? AppColors.dividerDark : AppColors.dividerLight,
        chipFill = isDark ? AppColors.surfaceDark.withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.95),
        chipBorder = isDark ? AppColors.dividerDark : AppColors.dividerLight,
        avatarRing = isDark ? AppColors.dividerDark : AppColors.dividerLight,
        backgroundGradient = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [
                  AppColors.backgroundDark,
                  Color.lerp(AppColors.backgroundDark, const Color(0xFF121A2A), 0.55)!,
                ]
              : [
                  AppColors.backgroundLight,
                  const Color(0xFFE2E6F3),
                ],
        );

  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color panelFill;
  final Color panelBorder;
  final Color chipFill;
  final Color chipBorder;
  final Color avatarRing;
  final LinearGradient backgroundGradient;
}

class _SoftOrb extends StatelessWidget {
  const _SoftOrb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}

class _IncomingSupportBrandingAvatar extends StatelessWidget {
  const _IncomingSupportBrandingAvatar({required this.palette});

  final _IncomingPalette palette;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 128.w,
        height: 128.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: palette.avatarRing, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.28),
              blurRadius: 32,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        padding: EdgeInsets.all(4.w),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
          child: ClipOval(
            child: Padding(
              padding: EdgeInsets.all(20.w),
              child: Image.asset(
                kCallKitSupportAvatarAsset,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IncomingAvatarRing extends StatelessWidget {
  const _IncomingAvatarRing({required this.initials, required this.palette});

  final String initials;
  final _IncomingPalette palette;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 128.w,
        height: 128.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: palette.avatarRing, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.28),
              blurRadius: 32,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        padding: EdgeInsets.all(4.w),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Text(
              initials.isEmpty ? '?' : initials,
              style: TextStyle(
                fontSize: 40.sp,
                fontFamily: 'Lexend',
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpeakerRow extends StatelessWidget {
  const _SpeakerRow({
    required this.call,
    required this.palette,
    required this.ref,
  });

  final CallState call;
  final _IncomingPalette palette;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => ref.read(callProvider.notifier).toggleSpeaker(),
        borderRadius: BorderRadius.circular(18.r),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
          decoration: BoxDecoration(
            color: palette.chipFill,
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(color: palette.chipBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                call.isSpeakerOn ? Symbols.volume_up : Symbols.hearing,
                fill: 1,
                color: call.isSpeakerOn ? AppColors.primary : palette.textSecondary,
                size: 22.sp,
              ),
              SizedBox(width: 10.w),
              Text(
                call.isSpeakerOn ? 'call_speaker'.tr() : 'call_earpiece'.tr(),
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 13.sp,
                  fontFamily: 'Lexend',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _IncomingActionVariant { decline, accept }

class _IncomingAction extends StatelessWidget {
  const _IncomingAction({
    required this.icon,
    required this.label,
    required this.variant,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final _IncomingActionVariant variant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isAccept = variant == _IncomingActionVariant.accept;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72.w,
            height: 72.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isAccept
                  ? const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isAccept ? null : Colors.transparent,
              border: isAccept ? null : Border.all(color: AppColors.error.withValues(alpha: 0.85), width: 2),
              boxShadow: isAccept
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              icon,
              fill: 1,
              color: isAccept ? Colors.white : AppColors.error,
              size: 32.sp,
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            label,
            style: TextStyle(
              color: isAccept ? AppColors.primary : AppColors.error,
              fontSize: 13.sp,
              fontFamily: 'Lexend',
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
