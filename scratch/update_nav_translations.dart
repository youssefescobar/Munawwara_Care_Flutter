
import 'dart:convert';
import 'dart:io';

void main() {
  final languages = ['en', 'ar', 'fr', 'tr', 'id', 'ur'];
  final translations = {
    'en': {
      'nav_groups': 'GROUPS',
      'nav_provisioning': 'PROVISIONING',
      'nav_reminders': 'REMINDERS',
      'nav_profile': 'PROFILE'
    },
    'ar': {
      'nav_groups': 'المجموعات',
      'nav_provisioning': 'التجهيز',
      'nav_reminders': 'التذكيرات',
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

  for (var lang in languages) {
    final file = File('c:/Users/drago/Desktop/projects/Durrah care mob app/Flutter_Munawwara/assets/translations/$lang.json');
    if (file.existsSync()) {
      final content = json.decode(file.readAsStringSync()) as Map<String, dynamic>;
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
