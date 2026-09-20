import sys
import io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
with open("android/app/src/main/kotlin/app/ibad_al_rahmann/NativePrayerManager.kt", "r", encoding="utf-8") as f:
    content = f.read()

target = '''    fun getArabicDate(context: Context, date: Date): String {
        try {
            val (hDay, hMonth, hYear) = getHijriDateComponents(context, date)'''

replacement = '''    fun getArabicDate(context: Context, date: Date): String {
        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val gDateStr = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.ENGLISH).format(date)
            val flutterHijri = prefs.getString("flutter.shared_hijri_date_$gDateStr", null) ?: prefs.getString("flutter.shared_hijri_date", null)
            
            // Only use shared_hijri_date if we are asking for today's date, or if we have exact match
            val isToday = gDateStr == java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.ENGLISH).format(Date())
            val matchedHijri = prefs.getString("flutter.shared_hijri_date_$gDateStr", null)
            
            if (!matchedHijri.isNullOrEmpty()) {
                return toArabicDigits(matchedHijri)
            } else if (isToday && !flutterHijri.isNullOrEmpty()) {
                return toArabicDigits(flutterHijri)
            }

            val (hDay, hMonth, hYear) = getHijriDateComponents(context, date)'''

if target in content:
    content = content.replace(target, replacement)
    with open("android/app/src/main/kotlin/app/ibad_al_rahmann/NativePrayerManager.kt", "w", encoding="utf-8") as f:
        f.write(content)
    print("Replaced getArabicDate")
else:
    print("Target not found")
