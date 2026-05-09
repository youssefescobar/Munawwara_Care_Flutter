import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dropdown_theme.dart';
import '../../models/provisioning_models.dart';
import 'provisioning_form_theme.dart';

class CreatePilgrimCard extends StatefulWidget {
  final bool isDark;
  final bool isProvisioning;
  final List<HotelOption> hotels;
  final List<BusOption> buses;
  final bool isLoadingResources;
  final Function(Map<String, dynamic> data) onCreate;

  const CreatePilgrimCard({
    super.key,
    required this.isDark,
    required this.isProvisioning,
    required this.hotels,
    required this.buses,
    required this.isLoadingResources,
    required this.onCreate,
  });

  @override
  State<CreatePilgrimCard> createState() => _CreatePilgrimCardState();
}

class _CreatePilgrimCardState extends State<CreatePilgrimCard> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _nationalIdCtrl = TextEditingController();
  final _medicalHistoryCtrl = TextEditingController();

  String _selectedLanguage = 'en';
  String _selectedVisaStatus = 'unknown';
  String _selectedEthnicity = 'Other';
  String? _selectedHotelId;
  String? _selectedRoomId;
  String? _selectedBusId;
  Set<String> _genderSelection = {'male'};

  static const List<Map<String, String>> _ethnicityOptions = [
    {'value': 'Arab', 'labelKey': 'ethnic_arab'},
    {'value': 'South Asian', 'labelKey': 'ethnic_south_asian'},
    {'value': 'Turkic', 'labelKey': 'ethnic_turkic'},
    {'value': 'Persian', 'labelKey': 'ethnic_persian'},
    {'value': 'Malay/Indonesian', 'labelKey': 'ethnic_malay_indo'},
    {'value': 'African', 'labelKey': 'ethnic_african'},
    {'value': 'Kurdish', 'labelKey': 'ethnic_kurdish'},
    {'value': 'Berber', 'labelKey': 'ethnic_berber'},
    {'value': 'European Muslim', 'labelKey': 'ethnic_european_muslim'},
    {'value': 'Other', 'labelKey': 'ethnic_other'},
  ];

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _phoneCtrl.dispose();
    _ageCtrl.dispose();
    _nationalIdCtrl.dispose();
    _medicalHistoryCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CreatePilgrimCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hotels == widget.hotels && oldWidget.buses == widget.buses) {
      return;
    }
    final hotelOk = _selectedHotelId == null ||
        widget.hotels.any((h) => h.id == _selectedHotelId);
    final busOk = _selectedBusId == null ||
        widget.buses.any((b) => b.id == _selectedBusId);
    var roomOk = true;
    if (_selectedRoomId != null) {
      final h =
          widget.hotels.where((x) => x.id == _selectedHotelId).firstOrNull;
      final rooms = (h?.rooms ?? const <RoomOption>[])
          .where((r) => r.active)
          .toList();
      roomOk = rooms.any((r) => r.id == _selectedRoomId);
    }
    if (hotelOk && roomOk && busOk) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        if (!hotelOk) {
          _selectedHotelId = null;
          _selectedRoomId = null;
        } else if (!roomOk) {
          _selectedRoomId = null;
        }
        if (!busOk) _selectedBusId = null;
      });
    });
  }

  void _handleSubmit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final selectedHotel =
        widget.hotels.where((h) => h.id == _selectedHotelId).firstOrNull;
    final selectedRoom =
        selectedHotel?.rooms.where((r) => r.id == _selectedRoomId).firstOrNull;
    final selectedBus =
        widget.buses.where((b) => b.id == _selectedBusId).firstOrNull;

    final data = {
      'full_name': _fullNameCtrl.text.trim(),
      'phone_number': _phoneCtrl.text.trim(),
      'national_id': _nationalIdCtrl.text.trim(),
      'medical_history': _medicalHistoryCtrl.text.trim(),
      'age': int.tryParse(_ageCtrl.text.trim()),
      'gender': _genderSelection.first,
      'language': _selectedLanguage,
      'ethnicity': _selectedEthnicity,
      'hotel_id': _selectedHotelId,
      'hotel_name': selectedHotel?.name,
      'room_id': _selectedRoomId,
      'room_number': selectedRoom?.roomNumber,
      'bus_id': _selectedBusId,
      'bus_info': selectedBus == null
          ? null
          : '${selectedBus.busNumber} - ${selectedBus.destination}',
      'visa': {'status': _selectedVisaStatus},
    };

    widget.onCreate(data);
  }

  Icon _prefix(IconData icon, Color muted) =>
      Icon(icon, size: 20.sp, color: muted);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textMuted =
        widget.isDark ? AppColors.textMutedLight : AppColors.textMutedDark;
    final textPrimary =
        widget.isDark ? AppColors.textLight : AppColors.textDark;
    final outline =
        widget.isDark ? AppColors.dividerDark : AppColors.dividerLight;

    final selectedHotel =
        widget.hotels.where((h) => h.id == _selectedHotelId).firstOrNull;
    final rooms = (selectedHotel?.rooms ?? const <RoomOption>[])
        .where((r) => r.active)
        .toList();

    final g = ProvisioningFormTheme.gapMd(context);
    final gSm = ProvisioningFormTheme.gapSm(context);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: widget.isDark ? AppColors.surfaceDark : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
        side: BorderSide(
          color: outline.withValues(alpha: widget.isDark ? 0.9 : 0.65),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 20.h),
        child: Theme(
          data: theme.copyWith(
            inputDecorationTheme:
                ProvisioningFormTheme.inputDecorationTheme(widget.isDark),
            splashColor: AppColors.primary.withValues(alpha: 0.08),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Symbols.person_add,
                      color: AppColors.primary,
                      size: 24.sp,
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        'provisioning_create_account_title'.tr(),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontFamily: 'Lexend',
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: ProvisioningFormTheme.gapLg(context)),
                Text(
                  'provisioning_basic_information'.tr(),
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontFamily: 'Lexend',
                    fontWeight: FontWeight.w600,
                    color: textMuted,
                  ),
                ),
                SizedBox(height: gSm),
                AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _fullNameCtrl,
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const [AutofillHints.name],
                        textInputAction: TextInputAction.next,
                        decoration: ProvisioningFormTheme.fieldDecoration(
                          context: context,
                          isDark: widget.isDark,
                          hintText: 'reg_full_name'.tr(),
                          prefixIcon: _prefix(Symbols.person, textMuted),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'provisioning_required'.tr()
                            : null,
                      ),
                      SizedBox(height: g),
                      TextFormField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        autofillHints: const [AutofillHints.telephoneNumber],
                        textInputAction: TextInputAction.next,
                        decoration: ProvisioningFormTheme.fieldDecoration(
                          context: context,
                          isDark: widget.isDark,
                          hintText: 'reg_phone'.tr(),
                          prefixIcon: _prefix(Symbols.phone, textMuted),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'provisioning_required'.tr()
                            : null,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: g),
                Text(
                  'reg_gender'.tr(),
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontFamily: 'Lexend',
                    fontWeight: FontWeight.w600,
                    color: textMuted,
                  ),
                ),
                SizedBox(height: gSm),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment<String>(
                      value: 'male',
                      label: Text('reg_male'.tr()),
                      icon: Icon(Symbols.male, size: 18.sp),
                    ),
                    ButtonSegment<String>(
                      value: 'female',
                      label: Text('reg_female'.tr()),
                      icon: Icon(Symbols.female, size: 18.sp),
                    ),
                  ],
                  selected: _genderSelection,
                  onSelectionChanged: (next) =>
                      setState(() => _genderSelection = next),
                  multiSelectionEnabled: false,
                  emptySelectionAllowed: false,
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 12.h,
                    ),
                    side: BorderSide(color: outline),
                    foregroundColor: textMuted,
                    selectedForegroundColor: AppColors.primary,
                    selectedBackgroundColor:
                        AppColors.primary.withValues(alpha: 0.12),
                    textStyle: TextStyle(
                      fontFamily: 'Lexend',
                      fontWeight: FontWeight.w600,
                      fontSize: 13.sp,
                    ),
                  ),
                ),
                SizedBox(height: g),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: TextFormField(
                        controller: _ageCtrl,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        decoration: ProvisioningFormTheme.fieldDecoration(
                          context: context,
                          isDark: widget.isDark,
                          hintText: 'reg_age'.tr(),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'provisioning_required'.tr();
                          }
                          final n = int.tryParse(v.trim());
                          if (n == null || n < 1 || n > 120) {
                            return 'provisioning_invalid'.tr();
                          }
                          return null;
                        },
                      ),
                    ),
                    SizedBox(width: gSm),
                    Expanded(
                      flex: 7,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _selectedLanguage,
                        decoration: ProvisioningFormTheme.fieldDecoration(
                          context: context,
                          isDark: widget.isDark,
                          hintText: 'settings_language'.tr(),
                        ),
                        icon: AppDropdownTheme.menuTrailingIcon(),
                        dropdownColor:
                            AppDropdownTheme.menuBackground(widget.isDark),
                        borderRadius: AppDropdownTheme.menuBorderRadius(),
                        elevation: AppDropdownTheme.menuElevation(),
                        style: AppDropdownTheme.valueStyle(widget.isDark),
                        items: [
                          DropdownMenuItem(
                            value: 'en',
                            child: Text(
                              'lang_english'.tr(),
                              style: AppDropdownTheme.menuItemStyle(
                                widget.isDark,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'ar',
                            child: Text(
                              'lang_arabic'.tr(),
                              style: AppDropdownTheme.menuItemStyle(
                                widget.isDark,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'ur',
                            child: Text(
                              'lang_urdu'.tr(),
                              style: AppDropdownTheme.menuItemStyle(
                                widget.isDark,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'fr',
                            child: Text(
                              'lang_french'.tr(),
                              style: AppDropdownTheme.menuItemStyle(
                                widget.isDark,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'id',
                            child: Text(
                              'lang_indonesian'.tr(),
                              style: AppDropdownTheme.menuItemStyle(
                                widget.isDark,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'tr',
                            child: Text(
                              'lang_turkish'.tr(),
                              style: AppDropdownTheme.menuItemStyle(
                                widget.isDark,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _selectedLanguage = v!),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: g),
                _AdditionalDetailsExpansion(
                  isDark: widget.isDark,
                  textPrimary: textPrimary,
                  textMuted: textMuted,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: _selectedEthnicity,
                              decoration: ProvisioningFormTheme.fieldDecoration(
                                context: context,
                                isDark: widget.isDark,
                                hintText: 'ethnicity'.tr(),
                              ),
                              icon: AppDropdownTheme.menuTrailingIcon(),
                              dropdownColor: AppDropdownTheme.menuBackground(
                                widget.isDark,
                              ),
                              borderRadius:
                                  AppDropdownTheme.menuBorderRadius(),
                              elevation: AppDropdownTheme.menuElevation(),
                              style:
                                  AppDropdownTheme.valueStyle(widget.isDark),
                              items: _ethnicityOptions
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e['value'],
                                      child: Text(
                                        (e['labelKey'] ?? '').tr(),
                                        style:
                                            AppDropdownTheme.menuItemStyle(
                                          widget.isDark,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _selectedEthnicity = v!),
                            ),
                          ),
                          SizedBox(width: gSm),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: _selectedVisaStatus,
                              decoration: ProvisioningFormTheme.fieldDecoration(
                                context: context,
                                isDark: widget.isDark,
                                hintText: 'profile_visa_status'.tr(),
                              ),
                              icon: AppDropdownTheme.menuTrailingIcon(),
                              dropdownColor: AppDropdownTheme.menuBackground(
                                widget.isDark,
                              ),
                              borderRadius:
                                  AppDropdownTheme.menuBorderRadius(),
                              elevation: AppDropdownTheme.menuElevation(),
                              style:
                                  AppDropdownTheme.valueStyle(widget.isDark),
                              items: [
                                'unknown',
                                'pending',
                                'issued',
                                'rejected',
                                'expired',
                              ]
                                  .map(
                                    (s) => DropdownMenuItem(
                                      value: s,
                                      child: Text(
                                        'status_$s'.tr(),
                                        style:
                                            AppDropdownTheme.menuItemStyle(
                                          widget.isDark,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _selectedVisaStatus = v!),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: g),
                      DropdownButtonFormField<String?>(
                        isExpanded: true,
                        initialValue: _selectedHotelId,
                        decoration: ProvisioningFormTheme.fieldDecoration(
                          context: context,
                          isDark: widget.isDark,
                          hintText: 'group_hotel_name'.tr(),
                          prefixIcon: _prefix(Symbols.apartment, textMuted),
                        ),
                        icon: AppDropdownTheme.menuTrailingIcon(),
                        dropdownColor:
                            AppDropdownTheme.menuBackground(widget.isDark),
                        borderRadius: AppDropdownTheme.menuBorderRadius(),
                        elevation: AppDropdownTheme.menuElevation(),
                        style: AppDropdownTheme.valueStyle(widget.isDark),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text(
                              'group_no_hotel'.tr(),
                              style: AppDropdownTheme.menuItemStyle(
                                widget.isDark,
                              ),
                            ),
                          ),
                          ...widget.hotels.map(
                            (h) => DropdownMenuItem<String?>(
                              value: h.id,
                              child: Text(
                                h.name,
                                style: AppDropdownTheme.menuItemStyle(
                                  widget.isDark,
                                ),
                              ),
                            ),
                          ),
                        ],
                        onChanged: widget.isLoadingResources
                            ? null
                            : (v) {
                                setState(() {
                                  _selectedHotelId = v;
                                  _selectedRoomId = null;
                                });
                              },
                      ),
                      SizedBox(height: g),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String?>(
                              isExpanded: true,
                              initialValue: _selectedRoomId,
                              decoration:
                                  ProvisioningFormTheme.fieldDecoration(
                                context: context,
                                isDark: widget.isDark,
                                hintText: 'group_room_number'.tr(),
                                prefixIcon: _prefix(Symbols.bed, textMuted),
                              ),
                              icon: AppDropdownTheme.menuTrailingIcon(),
                              dropdownColor:
                                  AppDropdownTheme.menuBackground(
                                widget.isDark,
                              ),
                              borderRadius:
                                  AppDropdownTheme.menuBorderRadius(),
                              elevation: AppDropdownTheme.menuElevation(),
                              style:
                                  AppDropdownTheme.valueStyle(widget.isDark),
                              items: [
                                DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text(
                                    'group_no_room'.tr(),
                                    style:
                                        AppDropdownTheme.menuItemStyle(
                                      widget.isDark,
                                    ),
                                  ),
                                ),
                                ...rooms.map(
                                  (r) {
                                    final full =
                                        r.currentOccupancy >= r.capacity;
                                    final base =
                                        AppDropdownTheme.menuItemStyle(
                                      widget.isDark,
                                      fontSize: 13,
                                    );
                                    return DropdownMenuItem<String?>(
                                      value: r.id,
                                      child: Text(
                                        '${r.roomNumber}'
                                        '${r.floor != null ? ' (F${r.floor})' : ''}'
                                        ' - ${r.currentOccupancy}/'
                                        '${r.capacity}',
                                        style: full
                                            ? base.copyWith(
                                                color:
                                                    Colors.green.shade400,
                                              )
                                            : base,
                                      ),
                                    );
                                  },
                                ),
                              ],
                              onChanged: selectedHotel == null
                                  ? null
                                  : (v) => setState(
                                        () => _selectedRoomId = v,
                                      ),
                            ),
                          ),
                          SizedBox(width: gSm),
                          Expanded(
                            child: DropdownButtonFormField<String?>(
                              isExpanded: true,
                              initialValue: _selectedBusId,
                              decoration:
                                  ProvisioningFormTheme.fieldDecoration(
                                context: context,
                                isDark: widget.isDark,
                                hintText: 'group_bus_number'.tr(),
                                prefixIcon: _prefix(
                                  Symbols.directions_bus,
                                  textMuted,
                                ),
                              ),
                              icon: AppDropdownTheme.menuTrailingIcon(),
                              dropdownColor:
                                  AppDropdownTheme.menuBackground(
                                widget.isDark,
                              ),
                              borderRadius:
                                  AppDropdownTheme.menuBorderRadius(),
                              elevation: AppDropdownTheme.menuElevation(),
                              style:
                                  AppDropdownTheme.valueStyle(widget.isDark),
                              items: [
                                DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text(
                                    'group_no_bus'.tr(),
                                    style:
                                        AppDropdownTheme.menuItemStyle(
                                      widget.isDark,
                                    ),
                                  ),
                                ),
                                ...widget.buses.map(
                                  (b) => DropdownMenuItem<String?>(
                                    value: b.id,
                                    child: Text(
                                      b.destination.isEmpty
                                          ? b.busNumber
                                          : '${b.busNumber} — '
                                              '${b.destination}',
                                      style:
                                          AppDropdownTheme.menuItemStyle(
                                        widget.isDark,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (v) =>
                                  setState(() => _selectedBusId = v),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: g),
                      TextFormField(
                        controller: _nationalIdCtrl,
                        textCapitalization: TextCapitalization.characters,
                        decoration: ProvisioningFormTheme.fieldDecoration(
                          context: context,
                          isDark: widget.isDark,
                          hintText: 'reg_passport'.tr(),
                          prefixIcon: _prefix(Symbols.badge, textMuted),
                        ),
                      ),
                      SizedBox(height: g),
                      TextFormField(
                        controller: _medicalHistoryCtrl,
                        maxLines: 2,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: ProvisioningFormTheme.fieldDecoration(
                          context: context,
                          isDark: widget.isDark,
                          hintText: 'reg_medical'.tr(),
                          prefixIcon:
                              _prefix(Symbols.medical_services, textMuted),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: ProvisioningFormTheme.gapLg(context)),
                FilledButton(
                  onPressed: widget.isProvisioning ? null : _handleSubmit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: widget.isProvisioning
                      ? SizedBox(
                          height: 22.h,
                          width: 22.h,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Symbols.add_circle, size: 20.sp),
                            SizedBox(width: 8.w),
                            Text(
                              'reg_create_account'.tr(),
                              style: TextStyle(
                                fontFamily: 'Lexend',
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdditionalDetailsExpansion extends StatelessWidget {
  const _AdditionalDetailsExpansion({
    required this.isDark,
    required this.textPrimary,
    required this.textMuted,
    required this.child,
  });

  final bool isDark;
  final Color textPrimary;
  final Color textMuted;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dividerClr =
        isDark ? AppColors.dividerDark : AppColors.dividerLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 4.h),
          child: Divider(height: 1, thickness: 1, color: dividerClr),
        ),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            maintainState: true,
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.only(top: 4.h, bottom: 4.h),
            backgroundColor: Colors.transparent,
            collapsedBackgroundColor: Colors.transparent,
            shape: const RoundedRectangleBorder(side: BorderSide.none),
            collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
            iconColor: AppColors.primary,
            collapsedIconColor: AppColors.primary,
            initiallyExpanded: false,
            title: Text(
              'provisioning_additional_details'.tr(),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontFamily: 'Lexend',
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
            ),
            subtitle: Padding(
              padding: EdgeInsets.only(top: 4.h),
              child: Text(
                'provisioning_optional_logistics'.tr(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'Lexend',
                      fontWeight: FontWeight.w500,
                      fontSize: 12.5.sp,
                      color: textMuted.withValues(alpha: 0.95),
                    ),
              ),
            ),
            children: [child],
          ),
        ),
      ],
    );
  }
}
