
import 'dart:convert';
import 'dart:io';

void main() {
  final languages = ['en', 'ar', 'fr', 'tr', 'id', 'ur'];
  final navKeys = {
    'en': {
      'nav_groups': 'GROUPS',
      'nav_provisioning': 'PROVISIONING',
      'nav_reminders': 'REMINDERS',
      'nav_profile': 'PROFILE'
    },
    'ar': {
      'nav_groups': 'المجموعات',
      'nav_provisioning': 'التجهیز',
      'nav_reminders': 'التذكیرات',
      'nav_profile': 'الملف الشخصي'
    },
    'fr': {
      'nav_groups': 'GROUPES',
      'nav_provisioning': 'PROVISIONNEMENT',
      'nav_reminders': 'RAPPELS',
      'nav_profile': 'PROFIL'
    },
    'tr': {
      'nav_groups': 'GRUPLAR',
      'nav_provisioning': 'HAZIRLIK',
      'nav_reminders': 'HATIRLATICILAR',
      'nav_profile': 'PROFİL'
    },
    'id': {
      'nav_groups': 'GRUP',
      'nav_provisioning': 'PROVISI',
      'nav_reminders': 'PENGINGAT',
      'nav_profile': 'PROFIL'
    },
    'ur': {
      'nav_groups': 'گروپس',
      'nav_provisioning': 'فراہمی',
      'nav_reminders': 'یاد دہانیاں',
      'nav_profile': 'پروفائل'
    }
  };
  
  final refreshKeys = {
    'en': {
      'group_refresh_login_title': 'Refresh Login Code',
      'group_refresh_login_confirm': 'Refresh Code',
      'group_refresh_login_body': 'Are you sure you want to refresh the login code for {}? This will immediately log them out of their current device.',
    },
    'ar': {
      'group_refresh_login_title': 'تحديث رمز الدخول',
      'group_refresh_login_confirm': 'تحديث الرمز',
      'group_refresh_login_body': 'هل أنت متأكد أنك تريد تحديث رمز الدخول لـ {}؟ سيؤدي هذا إلى تسجيل خروجهم فوراً من جهازهم الحالي.',
    },
    'fr': {
      'group_refresh_login_title': 'Actualiser le code de connexion',
      'group_refresh_login_confirm': 'Actualiser le code',
      'group_refresh_login_body': 'Êtes-vous sûr de vouloir actualiser le code de connexion pour {} ? Cela les déconnectera immédiatement de leur appareil actuel.',
    },
    'tr': {
      'group_refresh_login_title': 'Giriş Kodunu Yenile',
      'group_refresh_login_confirm': 'Kodu Yenile',
      'group_refresh_login_body': '{} için giriş kodunu yenilemek istediğinizden emin misiniz? Bu, onları mevcut cihazlarından hemen çıkaracaktır.',
    },
    'id': {
      'group_refresh_login_title': 'Segarkan Kode Login',
      'group_refresh_login_confirm': 'Segarkan Kode',
      'group_refresh_login_body': 'Apakah Anda yakin ingin menyegarkan kode login untuk {}? Ini akan segera mengeluarkan mereka dari perangkat saat ini.',
    },
    'ur': {
      'group_refresh_login_title': 'لاگ ان کوڈ کو تازہ کریں',
      'group_refresh_login_confirm': 'کوڈ کو تازہ کریں',
      'group_refresh_login_body': 'کیا آپ واقعی {} کے لیے لاگ ان کوڈ کو تازہ کرنا چاہتے ہیں؟ یہ انہیں فوری طور سے ان کے موجودہ آلے سے لاگ آؤٹ کر دے گا۔',
    }
  };

  for (var lang in languages) {
    final file = File('c:/Users/drago/Desktop/projects/Durrah care mob app/Flutter_Munawwara/assets/translations/$lang.json');
    if (file.existsSync()) {
      Map<String, dynamic> content = json.decode(file.readAsStringSync()) as Map<String, dynamic>;
      content.addAll(navKeys[lang]!);
      content.addAll(refreshKeys[lang]!);
      
      const encoder = JsonEncoder.withIndent('    ');
      file.writeAsStringSync(encoder.convert(content));
      print('Updated $lang.json - total keys: ${content.length}');
    }
  }
}
