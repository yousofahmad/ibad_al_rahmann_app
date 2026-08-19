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
 * • Full-screen overlay مع خلفية شفافة تمرر اللمسات للتطبيق خلفها
 * • الأزرار فقط هي التي تستقبل اللمسات
 * • زر "صليت والله" → يُظهر شاشة إنجاز "الحمد لله!" مع الـ Streak
 * • زر "ذكرني لاحقاً" → يُخفي الشاشة ويُعيدها بعد N دقائق
 * • Streak يُعاد حسابه من السجل الفعلي (لا يزيد ببساطة ++)
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
        snoozeRunnable?.let { snoozeHandler?.removeCallbacks(it) }
        snoozeHandler = null
        snoozeRunnable = null
    }

    // ─── Pre-Adhan Reminder Overlay ───────────────────────────────────────────

    fun showPreAdhan(context: Context, prayerName: String, alarmId: Int, minutesBefore: Int) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            !android.provider.Settings.canDrawOverlays(context)) return
        Handler(Looper.getMainLooper()).post {
            try {
                dismiss(context)
                val dm = context.resources.displayMetrics
                val screenW = dm.widthPixels
                val isDark = isDarkMode(context)
                val goldDark  = 0xFF8B5E1A.toInt()
                val subColor  = if (isDark) 0xFFAAAAAA.toInt() else 0xFF666666.toInt()
                val cardBg    = if (isDark) 0xF2121212.toInt() else 0xF5FFFFFF.toInt()

                // ── البطاقة المركزية ──────────────────────────────────────────
                val card = android.widget.LinearLayout(context).apply {
                    orientation = android.widget.LinearLayout.VERTICAL
                    gravity = Gravity.CENTER_HORIZONTAL
                    setPadding(dpToPx(dm, 32), dpToPx(dm, 48), dpToPx(dm, 32), dpToPx(dm, 40))
                    background = buildCardBackground(cardBg)
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
                    else       -> "ic_fajr"
                }
                val iconView = android.widget.ImageView(context).apply {
                    try {
                        val id = context.resources.getIdentifier(imgName, "drawable", context.packageName)
                        if (id != 0) setImageResource(id)
                    } catch (_: Exception) {}
                    val sz = dpToPx(dm, 80)
                    layoutParams = android.widget.LinearLayout.LayoutParams(sz, sz)
                        .apply { gravity = Gravity.CENTER; bottomMargin = dpToPx(dm, 16) }
                }

                val timeView = android.widget.TextView(context).apply {
                    text = "باقي $minutesBefore دقيقة على أذان $prayerName"
                    textSize = 16f; gravity = Gravity.CENTER
                    setTextColor(subColor)
                    setPadding(0, 0, 0, dpToPx(dm, 32))
                }

                val dismissBtn = buildFullWidthButton(
                    context, "تم — جزاك الله خيراً", goldDark, 0xFFFFFFFF.toInt(), 16f, 0, 20f
                )
                dismissBtn.setOnClickListener { dismiss(context) }

                card.addView(iconView)
                card.addView(timeView)
                card.addView(dismissBtn)

                val cardW = if (screenW / dm.density >= 600)
                    dpToPx(dm, 440) else (screenW * 0.9f).toInt()

                val lType = overlayLayerType()
                val flags = WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                        WindowManager.LayoutParams.FLAG_DIM_BEHIND or
                        WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE

                val params = WindowManager.LayoutParams(
                    cardW,
                    WindowManager.LayoutParams.WRAP_CONTENT,
                    lType, flags, PixelFormat.TRANSLUCENT
                ).apply {
                    gravity = Gravity.CENTER
                    dimAmount = 0.7f
                }

                overlayView = card
                (context.getSystemService(Context.WINDOW_SERVICE) as WindowManager).addView(card, params)
                NativeLogger.log(context, "PreAdhan overlay shown for $prayerName (${minutesBefore}min before)")
            } catch (e: Exception) {
                e.printStackTrace()
                NativeLogger.log(context, "PreAdhan overlay ERROR: ${e.message}")
            }
        }
    }

    // ─── Show ─────────────────────────────────────────────────────────────────

    fun show(context: Context, prayerName: String, alarmId: Int) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        if (!prefs.getBoolean("flutter.prayer_focus_enabled", false)) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            !android.provider.Settings.canDrawOverlays(context)) return

        dismiss(context)

        Handler(Looper.getMainLooper()).post {
            try {
                val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
                val view = buildOverlayView(context, prayerName, alarmId) ?: return@post
                overlayView = view

                val dm = context.resources.displayMetrics
                val screenW = dm.widthPixels
                val cardW = if (screenW / dm.density >= 600)
                    dpToPx(dm, 460) else (screenW * 0.92).toInt()

                val lType = overlayLayerType()
                // FLAG_NOT_TOUCH_MODAL: allows touches outside the modal card to pass through to background apps
                // FLAG_DIM_BEHIND: native OS dims entire screen behind the window
                val flags = WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                        WindowManager.LayoutParams.FLAG_DIM_BEHIND or
                        WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE

                val params = WindowManager.LayoutParams(
                    cardW,
                    WindowManager.LayoutParams.WRAP_CONTENT,
                    lType, flags, PixelFormat.TRANSLUCENT
                ).apply {
                    gravity = Gravity.CENTER
                    dimAmount = 0.7f
                }

                wm.addView(view, params)
                NativeLogger.log(context, "PrayerFocusOverlay shown for $prayerName (id: $alarmId)")
            } catch (e: Exception) {
                e.printStackTrace()
                NativeLogger.log(context, "PrayerFocusOverlay ERROR: ${e.message}")
            }
        }
    }

    // ─── Build Main Overlay View ──────────────────────────────────────────────

    private fun buildOverlayView(context: Context, prayerName: String, alarmId: Int): View? {
        val isDark = isDarkMode(context)
        val dm = context.resources.displayMetrics

        // Semi-transparent frosted background matching app theme
        val cardBg     = if (isDark) 0xEE1E1C1A.toInt() else 0xEEFAF8F5.toInt()
        val textColor  = if (isDark) 0xFFF0EAE1.toInt() else 0xFF1C1A18.toInt()
        val subColor   = if (isDark) 0xFFA89F94.toInt() else 0xFF6E655C.toInt()
        val goldColor  = if (isDark) 0xFFE0B880.toInt() else 0xFF9E6E2E.toInt()
        val goldDark   = if (isDark) 0xFF9E6E2E.toInt() else 0xFF8A5A1E.toInt()
        val snoozeBg   = if (isDark) 0x24D0A871.toInt() else 0x18000000.toInt()
        val snoozeText = if (isDark) 0xFFE0B880.toInt() else 0xFF8A5A1E.toInt()

        // ── Modernized, Larger Content Container ──────
        val card = android.widget.LinearLayout(context).apply {
            orientation = android.widget.LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            isClickable = true
            isFocusable = true
            background = buildCardBackground(cardBg)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) elevation = 24f
            setPadding(dpToPx(dm, 24), dpToPx(dm, 28), dpToPx(dm, 24), dpToPx(dm, 28))
        }

        // ── Rule 3: Retain circular prayer image prominently ────────────────
        val imageName = when {
            alarmId == 100 || alarmId == 110 || alarmId == 3000 || alarmId == 5000 -> "ic_fajr"
            alarmId == 101 || alarmId == 3001 || alarmId == 5001 ->
                if (Calendar.getInstance().get(Calendar.DAY_OF_WEEK) == Calendar.FRIDAY) "ic_jumuah_prayer" else "ic_dhuhr"
            alarmId == 102 || alarmId == 3002 || alarmId == 5002 -> "ic_asr"
            alarmId == 103 || alarmId == 3003 || alarmId == 5003 -> "ic_maghrib"
            alarmId == 104 || alarmId == 3004 || alarmId == 5004 -> "ic_isha"
            else -> "logo"
        }

        val iconView = android.widget.ImageView(context).apply {
            try {
                val resId = context.resources.getIdentifier(imageName, "drawable", context.packageName)
                if (resId != 0) setImageResource(resId)
            } catch (_: Exception) {}
            val size = dpToPx(dm, 92)
            layoutParams = android.widget.LinearLayout.LayoutParams(size, size).apply {
                gravity = Gravity.CENTER
                bottomMargin = dpToPx(dm, 4)
            }
        }

        val subtitleView = android.widget.TextView(context).apply {
            text = "حان وقت الصلاة"
            textSize = 13f; gravity = Gravity.CENTER
            setTextColor(subColor)
            setPadding(0, dpToPx(dm, 4), 0, dpToPx(dm, 2))
        }

        val prayerNameView = android.widget.TextView(context).apply {
            text = "صلاة $prayerName"
            textSize = 26f; gravity = Gravity.CENTER
            setTextColor(goldColor)
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            setPadding(0, 0, 0, dpToPx(dm, 2))
        }

        // Streak — يُحسب من السجل الفعلي
        val prayerStreak = recalculateTrueStreak(context)
        val streakView = android.widget.TextView(context).apply {
            text = if (prayerStreak > 0) "🔥 $prayerStreak صلاة متتالية" else "ابدأ سلسلة الصلاة اليوم"
            textSize = 14f; gravity = Gravity.CENTER
            setTextColor(if (prayerStreak > 0) 0xFFFF8C00.toInt() else subColor)
            setPadding(0, 0, 0, dpToPx(dm, 8))
        }

        // ── Rule 4: Timer & Progress Bar Section ─────────────────────────────
        val timerContainer = android.widget.LinearLayout(context).apply {
            orientation = android.widget.LinearLayout.VERTICAL
            setPadding(dpToPx(dm, 16), dpToPx(dm, 10), dpToPx(dm, 16), dpToPx(dm, 12))
            background = android.graphics.drawable.GradientDrawable().apply {
                setColor(if (isDark) 0x1AFFFFFF.toInt() else 0x0E000000.toInt())
                cornerRadius = 14f * dm.density
            }
            layoutParams = android.widget.LinearLayout.LayoutParams(
                android.widget.LinearLayout.LayoutParams.MATCH_PARENT,
                android.widget.LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = dpToPx(dm, 20)
            }
        }

        val nextPrayerInfo = getNextPrayerCountdownText(context)
        val countdownView = android.widget.TextView(context).apply {
            text = nextPrayerInfo
            textSize = 13f; gravity = Gravity.CENTER
            setTextColor(goldColor)
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            setPadding(0, 0, 0, dpToPx(dm, 8))
        }

        // Thick rounded progress bar
        val progressBar = android.widget.ProgressBar(context, null, android.R.attr.progressBarStyleHorizontal).apply {
            isIndeterminate = false
            progress = 65
            max = 100
            val h = dpToPx(dm, 8)
            layoutParams = android.widget.LinearLayout.LayoutParams(
                android.widget.LinearLayout.LayoutParams.MATCH_PARENT, h
            )
            val bgDrawable = android.graphics.drawable.GradientDrawable().apply {
                setColor(if (isDark) 0x26FFFFFF.toInt() else 0x1A000000.toInt())
                cornerRadius = 8f * dm.density
            }
            val progressDrawable = android.graphics.drawable.GradientDrawable().apply {
                setColor(goldColor)
                cornerRadius = 8f * dm.density
            }
            val clipProgress = android.graphics.drawable.ClipDrawable(
                progressDrawable, Gravity.START, android.graphics.drawable.ClipDrawable.HORIZONTAL
            )
            val layers = android.graphics.drawable.LayerDrawable(arrayOf(bgDrawable, clipProgress)).apply {
                setId(0, android.R.id.background)
                setId(1, android.R.id.progress)
            }
            this.progressDrawable = layers
        }

        timerContainer.addView(countdownView)
        timerContainer.addView(progressBar)

        // ── Rule 5: Action Buttons with full width and 20dp border radius ──────
        val prayedButton = buildFullWidthButton(
            context, "صليتُ والله ✓", goldDark, 0xFFFFFFFF.toInt(), 16f, dpToPx(dm, 10), 20f
        )

        // ── زر "ذكرني لاحقاً" ─────────────────────────────────────────────
        val prefs2 = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val snoozeMins = try {
            val bits = prefs2.getLong("flutter.focus_snooze_duration", -1L)
            if (bits != -1L) bits.toInt().coerceIn(1, 60) else prefs2.getInt("flutter.focus_snooze_duration", 5).coerceIn(1, 60)
        } catch (_: Exception) { 5 }

        val snoozeButton = buildFullWidthButton(
            context, "ذكرني بعد $snoozeMins دقائق (5)",
            snoozeBg, snoozeText, 13f, 0, 20f
        )
        snoozeButton.isEnabled = false
        snoozeButton.alpha = 0.4f

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

        prayedButton.setOnClickListener {
            countdownHandler.removeCallbacks(countdownRunnable)
            showConfirmationButtons(context, card, prayedButton, snoozeButton, prayerName, alarmId,
                goldColor, goldDark, subColor, textColor, isDark)
        }

        card.addView(iconView)
        card.addView(subtitleView)
        card.addView(prayerNameView)
        card.addView(streakView)
        card.addView(timerContainer)
        card.addView(prayedButton)
        card.addView(snoozeButton)
        return card
    }

    /** يُظهر زرّي التأكيد: "في وقتها" و"متأخراً" ويخفي زر التذكير بناءً على رغبة المستخدم */
    private fun showConfirmationButtons(
        context: Context,
        card: android.widget.LinearLayout,
        prayedButton: android.widget.Button,
        snoozeButton: android.widget.Button,
        prayerName: String,
        alarmId: Int,
        goldColor: Int, goldDark: Int, subColor: Int, textColor: Int, isDark: Boolean
    ) {
        prayedButton.visibility = View.GONE
        snoozeButton.visibility = View.GONE
        val dm = context.resources.displayMetrics

        val confirmLabel = android.widget.TextView(context).apply {
            text = "هل كانت في وقتها؟"
            textSize = 15f; gravity = Gravity.CENTER
            setTextColor(subColor)
            setPadding(0, 0, 0, dpToPx(dm, 10))
        }

        val row = android.widget.LinearLayout(context).apply {
            orientation = android.widget.LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 0)
        }

        val onTimeBtn = buildHalfButton(context, "في وقتها ✓", 0xFF2E7D32.toInt(), 0xFFFFFFFF.toInt(), 14f)
        val lateBtn   = buildHalfButton(context, "متأخراً  ⏳", 0xFFD84315.toInt(), 0xFFFFFFFF.toInt(), 14f)

        val halfP1 = android.widget.LinearLayout.LayoutParams(0, android.widget.LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            .apply { setMargins(0, 0, dpToPx(dm, 6), 0) }
        val halfP2 = android.widget.LinearLayout.LayoutParams(0, android.widget.LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            .apply { setMargins(dpToPx(dm, 6), 0, 0, 0) }

        onTimeBtn.layoutParams = halfP1
        lateBtn.layoutParams   = halfP2

        onTimeBtn.setOnClickListener { onPrayed(context, card, prayerName, alarmId, isOnTime = true, goldColor = goldColor) }
        lateBtn.setOnClickListener   { onPrayed(context, card, prayerName, alarmId, isOnTime = false, goldColor = goldColor) }

        row.addView(onTimeBtn)
        row.addView(lateBtn)

        val prayedIndex = card.indexOfChild(prayedButton)
        card.addView(confirmLabel, prayedIndex + 1)
        card.addView(row, prayedIndex + 2)
    }

    // ─── Actions ──────────────────────────────────────────────────────────────

    private fun onPrayed(
        context: Context,
        card: android.widget.LinearLayout,
        prayerName: String,
        alarmId: Int,
        isOnTime: Boolean,
        goldColor: Int
    ) {
        markPrayerInAccountability(context, prayerName)
        savePrayerLog(context, prayerName, if (isOnTime) "ontime" else "late")
        val newStreak = recalculateTrueStreak(context)
        NativeLogger.log(context, "PrayerFocus: $prayerName ✓ onTime=$isOnTime streak=$newStreak")

        // إظهار شاشة الإنجاز
        showAchievementScreen(context, card, prayerName, newStreak, goldColor)
    }

    /** يُظهر شاشة "الحمد لله!" مع Streak بعد تسجيل الصلاة (بدون شجرة) */
    private fun showAchievementScreen(
        context: Context,
        card: android.widget.LinearLayout,
        prayerName: String,
        streak: Int,
        goldColor: Int
    ) {
        val dm = context.resources.displayMetrics
        val isDark = isDarkMode(context)
        val textColor = if (isDark) 0xFFF0EAE1.toInt() else 0xFF1C1A18.toInt()
        val goldDark = if (isDark) 0xFF9E6E2E.toInt() else 0xFF8A5A1E.toInt()
        val streakBg = if (isDark) 0x33D0A871.toInt() else 0x14000000.toInt()

        card.removeAllViews()

        // ── الحمد لله! ────────────────────────────────────────────────────────
        val titleView = android.widget.TextView(context).apply {
            text = "الحمد لله!"
            textSize = 26f; gravity = Gravity.CENTER
            setTextColor(goldColor)
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            setPadding(0, dpToPx(dm, 8), 0, dpToPx(dm, 4))
        }

        val descView = android.widget.TextView(context).apply {
            text = "أتممت صلاة $prayerName تقبل الله منا ومنكم صالح الأعمال"
            textSize = 14f; gravity = Gravity.CENTER
            setTextColor(textColor)
            setPadding(0, 0, 0, dpToPx(dm, 16))
        }

        // ── بطاقة الـ Streak ────────────────────────────────────────────────
        val streakCard = android.widget.LinearLayout(context).apply {
            orientation = android.widget.LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dpToPx(dm, 16), dpToPx(dm, 12), dpToPx(dm, 16), dpToPx(dm, 16))
            background = android.graphics.drawable.GradientDrawable().apply {
                setColor(streakBg)
                cornerRadius = 16f * dm.density
            }
        }

        val streakNum = android.widget.TextView(context).apply {
            text = "🔥 $streak"
            textSize = 38f; gravity = Gravity.CENTER
            setTextColor(0xFFFF8C00.toInt())
            typeface = android.graphics.Typeface.DEFAULT_BOLD
        }

        val streakLabel = android.widget.TextView(context).apply {
            text = "صلوات متتالية دون انقطاع"
            textSize = 14f; gravity = Gravity.CENTER
            setTextColor(textColor)
            setPadding(0, dpToPx(dm, 4), 0, 0)
        }

        streakCard.addView(streakNum)
        streakCard.addView(streakLabel)

        val streakCardParams = android.widget.LinearLayout.LayoutParams(
            android.widget.LinearLayout.LayoutParams.MATCH_PARENT,
            android.widget.LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            bottomMargin = dpToPx(dm, 20)
        }
        streakCard.layoutParams = streakCardParams

        // ── زر "متابعة" ───────────────────────────────────────────────────────
        val continueBtn = buildFullWidthButton(
            context, "متابعة", goldDark, 0xFFFFFFFF.toInt(), 16f, 0
        )
        continueBtn.setOnClickListener { dismiss(context) }

        card.addView(titleView)
        card.addView(descView)
        card.addView(streakCard)
        card.addView(continueBtn)
    }

    private fun getNextPrayerCountdownText(context: Context): String {
        return try {
            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val nextName = prefs.getString("nextName", "") ?: ""
            val nextEpoch = prefs.getLong("next_prayer_time_epoch", 0L)
            if (nextEpoch > System.currentTimeMillis() && nextName.isNotEmpty()) {
                val diffMs = nextEpoch - System.currentTimeMillis()
                val hrs = diffMs / (3600 * 1000L)
                val mins = (diffMs % (3600 * 1000L)) / (60 * 1000L)
                "الصلاة القادمة: $nextName (باقي ${hrs}س و ${mins}د)"
            } else {
                ""
            }
        } catch (_: Exception) { "" }
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
        val prayerDayStr = resolveIslamicDay(prefs)

        val existingJson1 = prefs.getString("flutter.temp_prayers", null)
        val map1 = try {
            if (existingJson1 != null) JSONObject(existingJson1) else JSONObject()
        } catch (_: Exception) { JSONObject() }
        map1.put(prayerName, true)
        prefs.edit().putString("flutter.temp_prayers", map1.toString()).apply()
        prefs.edit().putString("flutter.current_day_date", prayerDayStr).apply()

        val existingJson2 = prefs.getString("flutter.temp_prayers_data", null)
        val map2 = try {
            if (existingJson2 != null) JSONObject(existingJson2) else JSONObject()
        } catch (_: Exception) { JSONObject() }
        map2.put(prayerName, true)
        prefs.edit().putString("flutter.temp_prayers_data", map2.toString()).apply()
    }

    private fun resolveIslamicDay(prefs: android.content.SharedPreferences): String {
        val sdf = SimpleDateFormat("yyyy-MM-dd", Locale.US)
        val now = System.currentTimeMillis()
        val cal = java.util.Calendar.getInstance()
        val todayStr = sdf.format(Date(now))

        val fajrKey = "flutter.fajr_epoch_today"
        val fajrEpoch = try {
            val raw = prefs.all[fajrKey]
            (raw as? Number)?.toLong() ?: raw?.toString()?.toLongOrNull() ?: -1L
        } catch (_: Exception) { -1L }

        if (fajrEpoch > 0 && now < fajrEpoch) {
            cal.timeInMillis = now
            cal.add(java.util.Calendar.DAY_OF_YEAR, -1)
            return sdf.format(cal.time)
        }
        return todayStr
    }

    private fun savePrayerLog(context: Context, prayerName: String, status: String) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val dayStr = resolveIslamicDay(prefs)
        val key = "flutter.prayer_focus_log_${dayStr}"
        val existingJson = prefs.getString(key, null)
        val map = try {
            if (existingJson != null) JSONObject(existingJson) else JSONObject()
        } catch (_: Exception) { JSONObject() }
        val entry = JSONObject().apply {
            put("status", status)
            put("ts", System.currentTimeMillis())
        }
        map.put(prayerName, entry)
        prefs.edit().putString(key, map.toString()).apply()
    }

    // ─── Streak Calculation (من السجل الفعلي) ────────────────────────────────

    fun getPrayerStreak(context: Context, prayerName: String): Int {
        return recalculateTrueStreak(context)
    }

    /**
     * يحسب الـ streak من سجل الصلوات الفعلي:
     * - يمشي للوراء يوماً بيوماً للصلوات المتتالية فقط
     */
    private fun recalculateTrueStreak(context: Context): Int {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val sdf = SimpleDateFormat("yyyy-MM-dd", Locale.US)
        var streak = 0
        var shouldContinue = true

        for (dayOffset in 0..60) {
            if (!shouldContinue) break
            val cal = Calendar.getInstance()
            cal.add(Calendar.DAY_OF_YEAR, -dayOffset)
            val dateStr = sdf.format(cal.time)
            val raw = prefs.getString("flutter.prayer_focus_log_$dateStr", null)
            val map = if (raw != null) try { JSONObject(raw) } catch (_: Exception) { JSONObject() } else JSONObject()

            val isFriday = cal.get(Calendar.DAY_OF_WEEK) == Calendar.FRIDAY
            val prayersInReverse = listOf("العشاء", "المغرب", "العصر", if (isFriday) "الجمعة" else "الظهر", "الفجر")

            if (dayOffset == 0) {
                var foundLatest = false
                for (k in prayersInReverse) {
                    val isLogged = map.has(k) && map.optJSONObject(k)?.optString("status")?.isNotEmpty() == true
                    if (isLogged) {
                        foundLatest = true
                        streak++
                    } else if (foundLatest) {
                        // A prayer between logged prayers was missed today -> streak ends
                        shouldContinue = false
                        break
                    }
                }
            } else {
                for (k in prayersInReverse) {
                    val isLogged = map.has(k) && map.optJSONObject(k)?.optString("status")?.isNotEmpty() == true
                    if (isLogged) {
                        streak++
                    } else {
                        shouldContinue = false
                        break
                    }
                }
            }
        }

        prefs.edit().putLong("flutter.prayer_streak_unified", streak.toLong()).apply()
        return streak
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────

    private fun overlayLayerType(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        else
            @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE
    }

    private fun dpToPx(dm: android.util.DisplayMetrics, dp: Int): Int {
        return (dp * dm.density).toInt()
    }

    /** زرار يأخذ العرض الكامل */
    private fun buildFullWidthButton(
        context: Context,
        text: String,
        bgColor: Int,
        textColor: Int,
        textSizeSp: Float,
        marginBottom: Int,
        cornerRadiusDp: Float = 28f
    ): android.widget.Button {
        val dm = context.resources.displayMetrics
        val bg = android.graphics.drawable.GradientDrawable().apply {
            setColor(bgColor)
            cornerRadius = cornerRadiusDp * dm.density
        }
        val paddingH = dpToPx(dm, 20)
        val paddingV = dpToPx(dm, 16)
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

    /** زرار يأخذ نصف العرض (للـ row) */
    private fun buildHalfButton(
        context: Context,
        text: String,
        bgColor: Int,
        textColor: Int,
        textSizeSp: Float,
        cornerRadiusDp: Float = 24f
    ): android.widget.Button {
        val dm = context.resources.displayMetrics
        val bg = android.graphics.drawable.GradientDrawable().apply {
            setColor(bgColor)
            cornerRadius = cornerRadiusDp * dm.density
        }
        return android.widget.Button(context).apply {
            this.text = text
            this.textSize = textSizeSp
            setTextColor(textColor)
            background = bg
            setPadding(dpToPx(dm, 12), dpToPx(dm, 14), dpToPx(dm, 12), dpToPx(dm, 14))
            isAllCaps = false
        }
    }

    private fun buildCardBackground(bgColor: Int): android.graphics.drawable.GradientDrawable {
        return android.graphics.drawable.GradientDrawable().apply {
            setColor(bgColor)
            // ركن علوي فقط مستدير (للـ bottom sheet effect)
            cornerRadii = floatArrayOf(48f, 48f, 48f, 48f, 0f, 0f, 0f, 0f)
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
