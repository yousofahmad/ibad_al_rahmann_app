class NotificationContentService {
  static const Map<String, String> notificationStrings = {
    "Fajr": "من صلى الفجر في جماعة فهو في ذمة الله",
    "Sunrise": "حان موعد الشروق",
    "Dhuhr": "لا تجعل عملك يلهيك عن أداء الصلاة",
    "Asr": "من ترك صلاة العصر حبط عمله",
    "Maghrib": "لا تزال أمتي بخير ما لم يؤخروا المغرب",
    "Isha": "من صلى العشاء في جماعة فكأنما قام نصف الليل",
    "Jumuah": "الجمعة إلى الجمعة كفارة لما بينهما",
    "PrePrayer": "اقترب موعد الصلاة", // نص افتراضي للتنبيه قبل الأذان
  };

  static String getNotificationBody(String prayerName) {
    if (prayerName == "الجمعة") {
      return notificationStrings["Jumuah"]!;
    }
    // Map Arabic names to keys if necessary, or pass English keys
    // Assuming prayerName passed is likely English key from PrayerTimes or Arabic display name
    // Let's handle Arabic display names mapping:
    switch (prayerName) {
      case "الفجر":
        return notificationStrings["Fajr"]!;
      case "الشروق":
        return notificationStrings["Sunrise"]!;
      case "الظهر":
        return notificationStrings["Dhuhr"]!;
      case "العصر":
        return notificationStrings["Asr"]!;
      case "المغرب":
        return notificationStrings["Maghrib"]!;
      case "العشاء":
        return notificationStrings["Isha"]!;
      default:
        return notificationStrings[prayerName] ?? "حى على الصلاة";
    }
  }
}
