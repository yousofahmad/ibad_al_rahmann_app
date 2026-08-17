package app.ibad_al_rahmann

import android.content.Context
import android.util.Log
import java.io.File
import java.io.FileWriter
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * NativeLogger — يكتب في ملف نصي + LogCat في نفس الوقت
 *
 * • الملف: context.filesDir/native_prayer_log.txt  (max 400 KB ثم يُعاد)
 * • LogCat tag: IbadAlRahman
 * • يمكن قراءة الملف من الإعدادات أو نسخه لمشاركته
 */
object NativeLogger {

    private const val TAG  = "IbadAlRahman"
    private const val FILE = "native_prayer_log.txt"
    private const val MAX_SIZE = 400 * 1024L  // 400 KB

    fun log(context: Context, message: String) {
        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            if (prefs.contains("flutter.enable_native_logging") &&
                !prefs.getBoolean("flutter.enable_native_logging", true)) return

            val sdf  = SimpleDateFormat("MM-dd HH:mm:ss.SSS", Locale.US)
            val time = sdf.format(Date())
            val line = "[$time] $message"

            // 1. LogCat — يظهر في adb logcat وفي Android Studio
            Log.d(TAG, message)

            // 2. ملف على الجهاز — يمكن مشاركته أو قراءته من الإعدادات
            val file = File(context.filesDir, FILE)
            if (file.exists() && file.length() > MAX_SIZE) {
                // احتفظ بنصف الملف الأخير عند الامتلاء (بدل حذفه كلياً)
                val content = file.readText()
                val half = content.substring(content.length / 2)
                file.writeText("... [truncated] ...\n$half")
            }
            FileWriter(file, true).use { fw ->
                fw.append("$line\n")
            }
        } catch (e: Exception) {
            Log.e(TAG, "NativeLogger error: ${e.message}")
        }
    }

    /** يُعيد مسار ملف اللوغ */
    fun getLogFile(context: Context): File = File(context.filesDir, FILE)

    /** يمسح ملف اللوغ */
    fun clear(context: Context) {
        try { File(context.filesDir, FILE).delete() } catch (_: Exception) {}
    }

    /** يُعيد محتوى آخر N سطراً من اللوغ */
    fun tail(context: Context, lines: Int = 200): String {
        return try {
            val file = File(context.filesDir, FILE)
            if (!file.exists()) return "Log file is empty."
            file.readLines().takeLast(lines).joinToString("\n")
        } catch (e: Exception) { "Error reading log: ${e.message}" }
    }
}