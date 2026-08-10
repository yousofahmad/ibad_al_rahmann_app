package app.ibad_al_rahmann

import android.content.Context
import java.io.File
import java.io.FileWriter
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object NativeLogger {
    fun log(context: Context, message: String) {
        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            // الافتراضي تفعيل السجل ما لم يقم المستخدم بإيقافه
            if (prefs.contains("flutter.enable_native_logging")) {
                if (prefs.getBoolean("flutter.enable_native_logging", true) == false) return
            }

            val file = File(context.filesDir, "native_prayer_log.txt")
            
            // Limit file size to ~200KB to prevent memory issues
            if (file.exists() && file.length() > 200 * 1024) {
                file.delete()
            }
            
            val fw = FileWriter(file, true)
            val sdf = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US)
            val time = sdf.format(Date())
            fw.append("[$time] $message\n")
            fw.flush()
            fw.close()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}