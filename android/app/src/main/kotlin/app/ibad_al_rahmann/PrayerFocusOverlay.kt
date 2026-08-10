package app.ibad_al_rahmann

import android.content.Context
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*

/**
 * PrayerFocusOverlay — شاشة التركيز للصلاة
 *
 * • خلفية شفافة + بطاقة مركزية فوق التطبيقات (FLAG_NOT_TOUCH_MODAL)
 * • زر "صليت والله" → يسأل: في وقتها أم متأخراً
 * • زر "ذكرني لاحقاً" → يُخفي الشاشة ويُعيدها بعد 5 دق بدون notification
 * • Streak لكل صلاة منفصل (5 سلاسل مستقلة)
 */
object PrayerFocusOverlay {

    private var overlayView: View? = null
    private var snoozeHandler: Handler? = null
    private var snoozeRunnable: Runnable? = null

    // ─── Dismiss ──────────────────────────────────────────────────────────────

    fun dismiss(context: Context) {
        overlayView?.let {
            try {
                val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
                wm.removeView(it)
            } catch (e: Exception) { e.printStackTrace() }
            overlayView = null
        }
        // إلغاء أي snooze مجدول
        snoozeRunnable?.let { snoozeHandler?.removeCallbacks(it) }
        snoozeHandler = null
        snoozeRunnable = null
    }

    // ـــ Pre-Adhan Reminder Overlay ــــــــــــــــــــــــــــــــــــــــــــــــــــــــــــــ

    fun showPreAdhan(context: Context, prayerName: String, alarmId: Int, minutesBefore: Int) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            !android.provider.Settings.canDrawOverlays(context)) return
        Handler(Looper.getMainLooper()).post {
            try {
                dismiss(context)
                val dm = context.resources.displayMetrics
                val isDark = isDarkMode(context)
                val cardBg   = if (isDark) 0xCC121212.toInt() else 0xF5FFFFFF.toInt()
                val textColor  = if (isDark) 0xFFFFFFFF.toInt() else 0xFF1A1A1A.toInt()
                val subColor   = if (isDark) 0xFFAAAAAA.toInt() else 0xFF666666.toInt()
                val goldColor = 0xFFD0A871.toInt()
                val goldDark  = 0xFF8B5E1A.toInt()

                val card = android.widget.LinearLayout(context).apply {
                    orientation = android.widget.LinearLayout.VERTICAL
                    gravity = Gravity.CENTER_HORIZONTAL
                    setPadding(72, 56, 72, 48)
                    background = buildCardBackground(cardBg, isDark)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) elevation = 24f
                }

                // أيقونة الصلاة
                val imgName = when (prayerName) {
                    "الفجر"   -> "ic_fajr"
                    "الظهر"   -> "ic_dhuhr"
                    "الجمعة" -> "ic_jumuah_prayer"
                    "العصر"   -> "ic_asr"
                    "المغرب" -> "ic_maghrib"
                    "العشاء" -> "ic_isha"
                    else          -> "ic_fajr"
                }
                val iconView = android.widget.ImageView(context).apply {
                    try {
                        val id = context.resources.getIdentifier(imgName, "drawable", context.packageName)
                        if (id != 0) setImageResource(id)
                    } catch (_: Exception) {}
                    val sz = (96 * dm.density).toInt()
                    layoutParams = android.widget.LinearLayout.LayoutParams(sz, sz).apply { gravity = Gravity.CENTER }
                }

                val timeView = android.widget.TextView(context).apply {
                    text = "باقي $minutesBefore دقيقة على أذان $prayerName"
                    textSize = 15f; gravity = Gravity.CENTER
                    setTextColor(subColor); setPadding(0, 20, 0, 40)
                }
                val dismissBtn = buildButton(context, "تم — جزاك الله خيراً",
                    goldDark, 0xFFFFFFFF.toInt(), 15f, 0)
                dismissBtn.setOnClickListener { dismiss(context) }

                card.addView(iconView); card.addView(timeView); card.addView(dismissBtn)

                val dpW = dm.widthPixels / dm.density
                val cardW = if (dpW >= 600) (480 * dm.density).toInt() else (dpW * 0.88f * dm.density).toInt()
                val lType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                else @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE

                val params = WindowManager.LayoutParams(
                    cardW, WindowManager.LayoutParams.WRAP_CONTENT, lType,
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED,
                    PixelFormat.TRANSLUCENT
                ).also { it.gravity = Gravity.CENTER }

                overlayView = card
                (context.getSystemService(Context.WINDOW_SERVICE) as WindowManager).addView(card, params)
                NativeLogger.log(context, "PreAdhan overlay shown for $prayerName (${minutesBefore}min before)")
            } catch (e: Exception) { e.printStackTrace() }
        }
    }

    // ─── Show ─────────────────────────────────────────────────────────────────

    fun show(context: Context, prayerName: String, alarmId: Int) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val isEnabled = prefs.getBoolean("flutter.prayer_focus_enabled", false)
        if (!isEnabled) return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            !android.provider.Settings.canDrawOverlays(context)) return

        dismiss(context)

        Handler(Looper.getMainLooper()).post {
            try {
                val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
                
                val displayMetrics = context.resources.displayMetrics
                val dpWidth = displayMetrics.widthPixels / displayMetrics.density
                val targetWidthDp = if (dpWidth >= 600) 480 else (dpWidth * 0.95).toInt()
                val cardWidth = (targetWidthDp * displayMetrics.density).toInt()

                val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                else
                    @Suppress("DEPRECATION")
                    WindowManager.LayoutParams.TYPE_PHONE

                val params = WindowManager.LayoutParams(
                    cardWidth,
                    WindowManager.LayoutParams.WRAP_CONTENT,
                    layoutType,
                    // FLAG_NOT_TOUCH_MODAL: passes touches outside the card to the underlying app
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED,
                    PixelFormat.TRANSLUCENT
                ).also { it.gravity = Gravity.CENTER }

                val view = buildOverlayView(context, prayerName, alarmId) ?: return@post
                overlayView = view
                wm.addView(view, params)

                NativeLogger.log(context, "PrayerFocusOverlay shown for $prayerName (id: $alarmId)")
            } catch (e: Exception) {
                e.printStackTrace()
                NativeLogger.log(context, "PrayerFocusOverlay ERROR: ${e.message}")
            }
        }
    }

    // ─── Build View ───────────────────────────────────────────────────────────

    private fun buildOverlayView(context: Context, prayerName: String, alarmId: Int): View? {
        val isDark = isDarkMode(context)
        val cardBg  = if (isDark) 0xCC000000.toInt() else 0xE8FFFFFF.toInt()
        val textColor  = if (isDark) 0xFFFFFFFF.toInt() else 0xFF1A1A1A.toInt()
        val subColor   = if (isDark) 0xFFAAAAAA.toInt() else 0xFF666666.toInt()
        val goldColor  = 0xFFD0A871.toInt()
        val goldDark   = 0xFF8B5E1A.toInt()

        // ── البطاقة المركزية (بدون خلفية تمنع اللمس) ─────────────────────
        val card = android.widget.LinearLayout(context).apply {
            orientation = android.widget.LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setBackgroundColor(cardBg)
            setPadding(72, 56, 72, 56)
            background = buildCardBackground(cardBg, isDark)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                elevation = 24f
            }
        }

        // البطاقة المركزية تأخذ أبعادها من WindowManager.LayoutParams مباشرة
        val displayMetrics = context.resources.displayMetrics

        // ── محتوى البطاقة ─────────────────────────────────────────────────────

        // الأيقونة المخصصة لكل صلاة
        val iconView = android.widget.ImageView(context).apply {
            val isFriday = Calendar.getInstance().get(Calendar.DAY_OF_WEEK) == Calendar.FRIDAY
            val imageName = when {
                alarmId == 100 || alarmId == 110 || alarmId == 3000 || alarmId == 5000 -> "ic_fajr"
                alarmId == 101 || alarmId == 3001 || alarmId == 5001 -> if (isFriday) "ic_jumuah_prayer" else "ic_dhuhr"
                alarmId == 102 || alarmId == 3002 || alarmId == 5002 -> "ic_asr"
                alarmId == 103 || alarmId == 3003 || alarmId == 5003 -> "ic_maghrib"
                alarmId == 104 || alarmId == 3004 || alarmId == 5004 -> "ic_isha"
                else -> "logo"
            }
            try {
                val resId = resources.getIdentifier(imageName, "drawable", context.packageName)
                if (resId != 0) {
                    setImageResource(resId)
                }
            } catch (e: Exception) {}
            
            // تحديد حجم الأيقونة
            val size = (96 * displayMetrics.density).toInt()
            layoutParams = android.widget.LinearLayout.LayoutParams(size, size).apply {
                gravity = Gravity.CENTER
            }
        }

        // "حان وقت الصلاة"
        val subtitleView = android.widget.TextView(context).apply {
            text = "حان وقت الصلاة"
            textSize = 14f
            gravity = Gravity.CENTER
            setTextColor(subColor)
            setPadding(0, 16, 0, 4)
        }

        // اسم الصلاة
        val prayerNameView = android.widget.TextView(context).apply {
            text = "صلاة $prayerName"
            textSize = 26f
            gravity = Gravity.CENTER
            setTextColor(goldColor)
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            setPadding(0, 0, 0, 4)
        }

        // Streak لهذه الصلاة تحديداً
        val prayerStreak = getPrayerStreak(context, prayerName)
        val streakView = android.widget.TextView(context).apply {
            text = if (prayerStreak > 0) "🔥 $prayerStreak صلاة متتالية" else "ابدأ سلسلة الصلاة اليوم"
            textSize = 15f
            gravity = Gravity.CENTER
            setTextColor(if (prayerStreak > 0) 0xFFFF8C00.toInt() else subColor)
            setPadding(0, 0, 0, 36)
        }

        // ── زر "صليتُ والله" ──────────────────────────────────────────────────
        val prayedButton = buildButton(
            context,
            text = "صليتُ والله ✓",
            bgColor = goldDark,
            textColor = 0xFFFFFFFF.toInt(),
            textSizeSp = 17f,
            marginBottom = 16
        )
        prayedButton.setOnClickListener {
            showConfirmationButtons(context, card, prayedButton, prayerName, alarmId,
                goldColor, goldDark, subColor, textColor, isDark)
        }

        // قراءة مدة التأجيل من إعدادات المستخدم
        val prefs2 = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val snoozeMins = try {
            val bits = prefs2.getLong("flutter.focus_snooze_duration", -1L)
            if (bits != -1L) bits.toInt().coerceIn(1, 60) else prefs2.getInt("flutter.focus_snooze_duration", 5).coerceIn(1, 60)
        } catch (e: Exception) {
            try {
                prefs2.getInt("flutter.focus_snooze_duration", 5).coerceIn(1, 60)
            } catch (e2: Exception) { 5 }
        }

        // زر "ذكرني لاحقاً" — يبدأ بعد استعداد 5 ثوان
        val snoozeButton = buildButton(
            context,
            text = "ذكرني بعد $snoozeMins دقائق (5)",
            bgColor = Color.TRANSPARENT,
            textColor = goldColor,
            textSizeSp = 14f,
            marginBottom = 0
        )
        snoozeButton.isEnabled = false
        snoozeButton.alpha = 0.45f
        
        // عداد تنازلي 5→4→3→2→1→0 ثم تفعيل الزر
        val countdownHandler = Handler(Looper.getMainLooper())
        var secondsLeft = 5
        val countdownRunnable = object : Runnable {
            override fun run() {
                secondsLeft--
                if (secondsLeft <= 0) {
                    snoozeButton.text = "ذكرني بعد $snoozeMins دقائق"
                    snoozeButton.isEnabled = true
                    snoozeButton.alpha = 1.0f
                } else {
                    snoozeButton.text = "ذكرني بعد $snoozeMins دقائق ($secondsLeft)"
                    countdownHandler.postDelayed(this, 1000L)
                }
            }
        }
        countdownHandler.postDelayed(countdownRunnable, 1000L)

        snoozeButton.setOnClickListener {
            countdownHandler.removeCallbacks(countdownRunnable)
            onSnooze(context, prayerName, alarmId, snoozeMins)
        }

        card.addView(iconView)
        card.addView(subtitleView)
        card.addView(prayerNameView)
        card.addView(streakView)
        card.addView(prayedButton)
        card.addView(snoozeButton)

        return card
    }

    /** يُظهر زرّي التأكيد: "في وقتها" و"متأخراً" ─── يحل محل زر "صليتُ والله" */
    private fun showConfirmationButtons(
        context: Context,
        card: android.widget.LinearLayout,
        prayedButton: android.widget.Button,
        prayerName: String,
        alarmId: Int,
        goldColor: Int, goldDark: Int, subColor: Int, textColor: Int, isDark: Boolean
    ) {
        // إخفاء زر صليت
        prayedButton.visibility = View.GONE

        // عنوان التأكيد
        val confirmLabel = android.widget.TextView(context).apply {
            text = "هل كانت في وقتها؟"
            textSize = 14f
            gravity = Gravity.CENTER
            setTextColor(subColor)
            setPadding(0, 0, 0, 16)
        }

        // صف الزرين
        val row = android.widget.LinearLayout(context).apply {
            orientation = android.widget.LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
        }

        val onTimeBtn = buildButton(context, "في وقتها ✓", 0xFF2E7D32.toInt(), 0xFFFFFFFF.toInt(), 14f, 0)
        val lateBtn   = buildButton(context, "متأخراً  ⏳", 0xFFE65100.toInt(), 0xFFFFFFFF.toInt(), 14f, 0)

        val halfParams = android.widget.LinearLayout.LayoutParams(0, android.widget.LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            .apply { setMargins(0, 0, 8, 0) }
        val halfParams2 = android.widget.LinearLayout.LayoutParams(0, android.widget.LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            .apply { setMargins(8, 0, 0, 0) }

        onTimeBtn.layoutParams = halfParams
        lateBtn.layoutParams   = halfParams2

        onTimeBtn.setOnClickListener { onPrayed(context, prayerName, alarmId, isOnTime = true) }
        lateBtn.setOnClickListener   { onPrayed(context, prayerName, alarmId, isOnTime = false) }

        row.addView(onTimeBtn)
        row.addView(lateBtn)

        // إضافتهم بعد زر "صليت" مباشرة
        val prayedIndex = card.indexOfChild(prayedButton)
        card.addView(confirmLabel, prayedIndex + 1)
        card.addView(row, prayedIndex + 2)
    }

    // ─── Actions ──────────────────────────────────────────────────────────────

    private fun onPrayed(context: Context, prayerName: String, alarmId: Int, isOnTime: Boolean) {
        markPrayerInAccountability(context, prayerName)
        updatePrayerStreak(context, prayerName)
        savePrayerLog(context, prayerName, if (isOnTime) "ontime" else "late")
        dismiss(context)
        
        // Removed notification canceling to keep the notification in the status bar per user request.

        NativeLogger.log(context, "PrayerFocus: $prayerName ✓ onTime=$isOnTime")
    }

    private fun onSnooze(context: Context, prayerName: String, alarmId: Int, snoozeMins: Int = 5) {
        dismiss(context)
        NativeLogger.log(context, "PrayerFocus: Snoozed $prayerName for $snoozeMins min")
        val h = Handler(Looper.getMainLooper())
        val r = Runnable { show(context, prayerName, alarmId) }
        snoozeHandler = h
        snoozeRunnable = r
        h.postDelayed(r, snoozeMins * 60 * 1000L)
    }

    // ─── Persistence ──────────────────────────────────────────────────────────

    private fun markPrayerInAccountability(context: Context, prayerName: String) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        // If the user prays after midnight but before Fajr, attribute it to the previous day
        val prayerDayStr = resolveIslamicDay(prefs)

        // 1. Update temp_prayers (for Accountability Screen)
        val existingJson1 = prefs.getString("flutter.temp_prayers", null)
        val map1 = try {
            if (existingJson1 != null) JSONObject(existingJson1) else JSONObject()
        } catch (e: Exception) { JSONObject() }
        map1.put(prayerName, true)
        prefs.edit().putString("flutter.temp_prayers", map1.toString()).apply()
        
        // Prevent Flutter from wiping temp_prayers on cold boot by setting current_day_date
        prefs.edit().putString("flutter.current_day_date", prayerDayStr).apply()

        // 2. Update temp_prayers_data (for Prayer Focus / Salaty Screen)
        val existingJson2 = prefs.getString("flutter.temp_prayers_data", null)
        val map2 = try {
            if (existingJson2 != null) JSONObject(existingJson2) else JSONObject()
        } catch (e: Exception) { JSONObject() }
        map2.put(prayerName, true)
        prefs.edit().putString("flutter.temp_prayers_data", map2.toString()).apply()
    }

    /**
     * Returns the Islamic-day date string (yyyy-MM-dd).
     * Between midnight and Fajr the Islamic day is still the *previous* calendar date,
     * so Isha prayed at e.g. 01:00 AM is logged under the correct day.
     */
    private fun resolveIslamicDay(prefs: android.content.SharedPreferences): String {
        val sdf = SimpleDateFormat("yyyy-MM-dd", Locale.US)
        val now = System.currentTimeMillis()
        val cal = java.util.Calendar.getInstance()
        val todayStr = sdf.format(Date(now))

        // Try to read today's Fajr epoch from SharedPreferences (stored by Flutter as ms)
        // Key pattern used by prayer_service.dart: flutter.fajr_epoch_today
        val fajrKey = "flutter.fajr_epoch_today"
        val fajrEpoch = try {
            val raw = prefs.all[fajrKey]
            (raw as? Number)?.toLong() ?: raw?.toString()?.toLongOrNull() ?: -1L
        } catch (e: Exception) { -1L }

        // If current time is after midnight (00:00) and before Fajr → previous calendar day
        if (fajrEpoch > 0 && now < fajrEpoch) {
            // We are between midnight and Fajr — return yesterday's date string
            cal.timeInMillis = now
            cal.add(java.util.Calendar.DAY_OF_YEAR, -1)
            return sdf.format(cal.time)
        }
        return todayStr
    }

    /** حفظ سجل الصلاة مع الحالة: ontime / late / missed */
    private fun savePrayerLog(context: Context, prayerName: String, status: String) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        // Use the same Islamic-day resolution so the log entry lands on the correct date
        val dayStr = resolveIslamicDay(prefs)
        val key = "flutter.prayer_focus_log_${dayStr}"
        val existingJson = prefs.getString(key, null)
        val map = try {
            if (existingJson != null) JSONObject(existingJson) else JSONObject()
        } catch (e: Exception) { JSONObject() }
        val entry = JSONObject().apply {
            put("status", status)
            put("ts", System.currentTimeMillis())
        }
        map.put(prayerName, entry)
        prefs.edit().putString(key, map.toString()).apply()
    }

    // ─── Per-Prayer Streak ────────────────────────────────────────────────────

    fun getPrayerStreak(context: Context, prayerName: String): Int {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val unifiedKey = "flutter.prayer_streak_unified"
        var streak = 0
        try {
            val raw = prefs.all[unifiedKey]
            streak = (raw as? Number)?.toInt() ?: raw?.toString()?.toIntOrNull() ?: 0
        } catch (e: Exception) {}
        return streak
    }

    private fun updatePrayerStreak(context: Context, prayerName: String) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val unifiedKey = "flutter.prayer_streak_unified"
        
        var streak = 0
        try {
            val raw = prefs.all[unifiedKey]
            streak = (raw as? Number)?.toInt() ?: raw?.toString()?.toIntOrNull() ?: 0
        } catch (e: Exception) {}

        streak++
        
        prefs.edit().putLong(unifiedKey, streak.toLong()).apply()
        NativeLogger.log(context, "Unified Prayer Streak increased to $streak")
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────

    private fun buildButton(
        context: Context,
        text: String,
        bgColor: Int,
        textColor: Int,
        textSizeSp: Float,
        marginBottom: Int,
        cornerRadiusDp: Float = 28f
    ): android.widget.Button {
        val dm = context.resources.displayMetrics
        val cornerPx = cornerRadiusDp * dm.density
        val bg = android.graphics.drawable.GradientDrawable().apply {
            setColor(bgColor)
            cornerRadius = cornerPx
        }
        val paddingH = (20 * dm.density).toInt()
        val paddingV = (14 * dm.density).toInt()
        val btn = android.widget.Button(context).apply {
            this.text = text
            this.textSize = textSizeSp
            setTextColor(textColor)
            background = bg
            setPadding(paddingH, paddingV, paddingH, paddingV)
            isAllCaps = false
        }
        btn.layoutParams = android.widget.LinearLayout.LayoutParams(
            android.widget.LinearLayout.LayoutParams.MATCH_PARENT,
            android.widget.LinearLayout.LayoutParams.WRAP_CONTENT
        ).also { it.setMargins(0, 0, 0, marginBottom) }
        return btn
    }

    private fun buildCardBackground(bgColor: Int, isDark: Boolean): android.graphics.drawable.GradientDrawable {
        return android.graphics.drawable.GradientDrawable().apply {
            setColor(bgColor)
            cornerRadius = 48f
        }
    }

    private fun isDarkMode(context: Context): Boolean {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val mode = prefs.getString("flutter.themeMode", null)
        if (mode == "darkTheme") return true
        if (mode == "lightTheme") return false

        val nightModeFlags = context.resources.configuration.uiMode and
                android.content.res.Configuration.UI_MODE_NIGHT_MASK
        return nightModeFlags == android.content.res.Configuration.UI_MODE_NIGHT_YES
    }
}
