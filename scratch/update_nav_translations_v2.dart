
import 'dart:convert';
import 'dart:io';

void main() {
  final languages = ['en', 'ar', 'fr', 'tr', 'id', 'ur'];
  final translations = {
    'en': {
      'group_refresh_login_title': 'Refresh Login Code',
      'group_refresh_login_confirm': 'Refresh Code',
      'group_refresh_login_body': 'Are you sure you want to refresh the login code for {}? This will immediately log them out of their current device.',
      'nav_groups': 'GROUPS',
      'nav_provisioning': 'PROVISIONING',
      'nav_reminders': 'REMINDERS',
      'nav_profile': 'PROFILE'
    },
    'ar': {
      'group_refresh_login_title': 'تحديث رمز الدخول',
      'group_refresh_login_confirm': 'تحديث الرمز',
      'group_refresh_login_body': 'هل أنت متأكد أنك تريد تحديث رمز الدخول لـ {}؟ سيؤدي هذا إلى تسجيل خروجهم فوراً من جهازهم الحالي.',
      'nav_groups': 'المجموعات',
      'nav_provisioning': 'التجهيز',
      'nav_reminders': 'التذكيرات',
      'nav_profile': 'الملف الشخصي'
    },
    'fr': {
      'group_refresh_login_title': 'Actualiser le code de connexion',
      'group_refresh_login_confirm': 'Actualiser le code',
      'group_refresh_login_body': 'Êtes-vous sûr de vouloir actualiser le code de connexion pour {} ? Cela les déconnectera immédiatement de leur appareil actuel.',
      'nav_groups': 'GROUPES',
      'nav_provisioning': 'PROVISIONNEMENT',
      'nav_reminders': 'RAPPELS',
      'nav_profile': 'PROFIL'
    },
    'tr': {
      'group_refresh_login_title': 'Giriş Kodunu Yenile',
      'group_refresh_login_confirm': 'Kodu Yenile',
      'group_refresh_login_body': '{} için giriş kodunu yenilemek istediğinizden emin misiniz? Bu, onları mevcut cihazlarından hemen çıkaracaktır.',
      'nav_groups': 'GRUPLAR',
      'nav_provisioning': 'HAZIRLIK',
      'nav_reminders': 'HATIRLATICILAR',
      'nav_profile': 'PROFİL'
    },
    'id': {
      'group_refresh_login_title': 'Segarkan Kode Login',
      'group_refresh_login_confirm': 'Segarkan Kode',
      'group_refresh_login_body': 'Apakah Anda yakin ingin menyegarkan kode login untuk {}? Ini akan segera mengeluarkan mereka dari perangkat saat ini.',
      'nav_groups': 'GRUP',
      'nav_provisioning': 'PROVISI',
      'nav_reminders': 'PENGINGAT',
      'nav_profile': 'PROFIL'
    },
    'ur': {
      'group_refresh_login_title': 'لاگ ان کوڈ کو تازہ کریں',
      'group_refresh_login_confirm': 'کوڈ کو تازہ کریں',
      'group_refresh_login_body': 'کیا آپ واقعی {} کے لیے لاگ ان کوڈ کو تازہ کرنا چاہتے ہیں؟ یہ انہیں فوری طور سے ان کے موجودہ آلے سے لاگ آؤٹ کر دے گا۔',
      'nav_groups': 'گروپس',
      'nav_provisioning': 'فراہمی',
      'nav_reminders': 'یاد دہانیاں',
      'nav_profile': 'پروفائل'
    }
  };

  for (var lang in languages) {
    final file = File('c:/Users/drago/Desktop/projects/Durrah care mob app/Flutter_Munawwara/assets/translations/$lang.json');
    if (file.existsSync()) {
      String rawContent = file.readAsStringSync();
      // Simple cleaning if the file was corrupted by partial writes
      if (rawContent.contains('nav_groups') && !rawContent.trim().endsWith('}')) {
          // Attempt to fix broken JSON if necessary
          print('Warning: $lang.json seems truncated. Attempting fix.');
          if (!rawContent.trim().endsWith('}')) {
              rawContent += '}';
          }
      }
      
      Map<String, dynamic> content;
      try {
        content = json.decode(rawContent) as Map<String, dynamic>;
      } catch (e) {
        print('Error decoding $lang.json: $e');
        // Fallback: try to find the last valid comma and close it
        continue; 
      }
      
      final newKeys = translations[lang]!;
      content.addAll(newKeys);
      
      const encoder = JsonEncoder.withIndent('    ');
      file.writeAsStringSync(encoder.convert(content));
      print('Updated $lang.json');
    } else {
      print('File not found: ${file.path}');
    }
  }
}
