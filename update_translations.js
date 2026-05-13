const fs = require('fs');
const path = require('path');

const translations = {
  "en": {
    "msg_removed_from_group": "You have been removed from {}",
    "msg_force_logout": "Your login code was refreshed. You have been logged out.",
    "error_location_unavailable": "Could not get current location",
    "msg_sos_broadcast_sent": "🚨 SOS broadcast sent!",
    "msg_sos_broadcast_failed": "Failed to send SOS. Try again.",
    "msg_group_deleted": "\"{}\" deleted.",
    "msg_group_delete_failed": "Failed to delete group",
    "msg_already_in_lang": "This message already appears to be in {}."
  },
  "ar": {
    "msg_removed_from_group": "لقد تمت إزالتك من {}",
    "msg_force_logout": "تم تحديث رمز تسجيل الدخول الخاص بك. لقد تم تسجيل خروجك.",
    "error_location_unavailable": "تعذر الحصول على الموقع الحالي",
    "msg_sos_broadcast_sent": "🚨 تم إرسال نداء الاستغاثة!",
    "msg_sos_broadcast_failed": "فشل في إرسال نداء الاستغاثة. حاول مرة أخرى.",
    "msg_group_deleted": "تم حذف \"{}\".",
    "msg_group_delete_failed": "فشل في حذف المجموعة",
    "msg_already_in_lang": "يبدو أن هذه الرسالة مكتوبة بالفعل باللغة {}."
  },
  "ur": {
    "msg_removed_from_group": "آپ کو {} سے ہٹا دیا گیا ہے",
    "msg_force_logout": "آپ کا لاگ ان کوڈ ریفریش کر دیا گیا ہے۔ آپ لاگ آؤٹ ہو چکے ہیں۔",
    "error_location_unavailable": "موجودہ مقام حاصل نہیں کیا جا سکا",
    "msg_sos_broadcast_sent": "🚨 ہنگامی پیغام بھیج دیا گیا!",
    "msg_sos_broadcast_failed": "ہنگامی پیغام بھیجنے میں ناکامی۔ دوبارہ کوشش کریں۔",
    "msg_group_deleted": "\"{}\" حذف کر دیا گیا۔",
    "msg_group_delete_failed": "گروپ کو حذف کرنے میں ناکام",
    "msg_already_in_lang": "یہ پیغام پہلے ہی {} میں معلوم ہوتا ہے۔"
  },
  "fr": {
    "msg_removed_from_group": "Vous avez été retiré de {}",
    "msg_force_logout": "Votre code de connexion a été actualisé. Vous avez été déconnecté.",
    "error_location_unavailable": "Impossible d'obtenir la position actuelle",
    "msg_sos_broadcast_sent": "🚨 Diffusion SOS envoyée !",
    "msg_sos_broadcast_failed": "Échec de l'envoi du SOS. Réessayez.",
    "msg_group_deleted": "\"{}\" supprimé.",
    "msg_group_delete_failed": "Échec de la suppression du groupe",
    "msg_already_in_lang": "Ce message semble déjà être en {}."
  },
  "id": {
    "msg_removed_from_group": "Anda telah dihapus dari {}",
    "msg_force_logout": "Kode masuk Anda telah diperbarui. Anda telah keluar.",
    "error_location_unavailable": "Tidak bisa mendapatkan lokasi saat ini",
    "msg_sos_broadcast_sent": "🚨 Siaran SOS terkirim!",
    "msg_sos_broadcast_failed": "Gagal mengirim SOS. Coba lagi.",
    "msg_group_deleted": "\"{}\" dihapus.",
    "msg_group_delete_failed": "Gagal menghapus grup",
    "msg_already_in_lang": "Pesan ini sepertinya sudah dalam bahasa {}."
  },
  "tr": {
    "msg_removed_from_group": "{} grubundan çıkarıldınız",
    "msg_force_logout": "Giriş kodunuz yenilendi. Çıkış yaptınız.",
    "error_location_unavailable": "Geçerli konum alınamadı",
    "msg_sos_broadcast_sent": "🚨 SOS yayını gönderildi!",
    "msg_sos_broadcast_failed": "SOS gönderilemedi. Tekrar deneyin.",
    "msg_group_deleted": "\"{}\" silindi.",
    "msg_group_delete_failed": "Grup silinemedi",
    "msg_already_in_lang": "Bu mesaj zaten {} dilinde gibi görünüyor."
  }
};

const dir = path.join(__dirname, 'assets', 'translations');

Object.keys(translations).forEach(lang => {
  const filePath = path.join(dir, `${lang}.json`);
  if (fs.existsSync(filePath)) {
    const dataStr = fs.readFileSync(filePath, 'utf8').replace(/^\uFEFF/, '');
    const data = JSON.parse(dataStr);
    const toAdd = translations[lang];
    let changed = false;
    for (const key in toAdd) {
      if (!data[key]) {
        data[key] = toAdd[key];
        changed = true;
      }
    }
    if (changed) {
      fs.writeFileSync(filePath, JSON.stringify(data, null, 2) + '\n');
      console.log(`Updated ${lang}.json`);
    } else {
      console.log(`${lang}.json already has all keys`);
    }
  } else {
    console.log(`${lang}.json not found!`);
  }
});
