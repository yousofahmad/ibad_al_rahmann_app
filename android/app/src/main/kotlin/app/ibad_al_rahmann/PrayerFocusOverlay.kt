package app.ibad_al_rahmann

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.os.CountDownTimer
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*

/**
 * PrayerFocusOverlay — شاشة التركيز للصلاة النيتف (Native Kotlin Overlay)
 *
 * • Split-Window Touch Hack:
 *   - VisualsView: Full-screen (MATCH_PARENT x MATCH_PARENT) dark backdrop + prayer info.
 *     Flags: FLAG_NOT_TOUCHABLE | FLAG_NOT_FOCUSABLE. ALL touches pass through to apps underneath!
 *   - ControlsView: Bottom aligned (MATCH_PARENT x WRAP_CONTENT) with transparent background.
 *     Flags: FLAG_NOT_TOUCH_MODAL | FLAG_NOT_FOCUSABLE. Intercepts touches ONLY on the buttons!
 * • عداد زمني حي دقيق بالثواني يحسب الوقت المتبقي على الصلاة القادمة.
 * • تطابق تام بين وضع المعاينة (Preview) والوضع الحي (Live).
 */
object PrayerFocusOverlay {

    private var visualsView: View? = null
    private var controlsView: View? = null
    private var snoozeHandler: Handler? = null
    private var snoozeRunnable: Runnable? = null
    private var liveTimer: CountDownTimer? = null

    // ─── Dismiss ──────────────────────────────────────────────────────────────

    fun dismiss(context: Context) {
        val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        visualsView?.let {
            try { wm.removeView(it) } catch (e: Exception) { e.printStackTrace() }
            visualsView = null
        }
        controlsView?.let {
            try { wm.removeView(it) } catch (e: Exception) { e.printStackTrace() }
            controlsView = null
        }
        liveTimer?.cancel()
        liveTimer = null
    }

    fun cancelSnooze(context: Context) {
        snoozeRunnable?.let { snoozeHandler?.removeCallbacks(it) }
        snoozeHandler = null
        snoozeRunnable = null
        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
            val intent = Intent(context, AlarmReceiver::class.java)
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                8888,
                intent,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            )
            if (pendingIntent != null && alarmManager != null) {
                alarmManager.cancel(pendingIntent)
                pendingIntent.cancel()
            }
        } catch (_: Exception) {}
    }

    // ─── Pre-Adhan Reminder Overlay ───────────────────────────────────────────

    fun showPreAdhan(context: Context, prayerName: String, alarmId: Int, minutesBefore: Int) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            !android.provider.Settings.canDrawOverlays(context)) return
        Handler(Looper.getMainLooper()).post {
            try {
                dismiss(context)
                val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
                val dm = context.resources.displayMetrics
                val goldDark  = 0xFF9E6E2E.toInt()
                val goldColor = 0xFFE2BA84.toInt()
                val subColor  = 0xFFCCCCCC.toInt()
                val backdropBg = Color.argb(195, 12, 10, 8)

                // ── 1. Visuals View (Full-Screen, Touch-Passthrough) ──────────────────────────
                val visualsLayout = android.widget.FrameLayout(context).apply {
                    setBackgroundColor(backdropBg)
                }

                val centerContent = android.widget.LinearLayout(context).apply {
                    orientation = android.widget.LinearLayout.VERTICAL
                    gravity = Gravity.CENTER_HORIZONTAL
                    setPadding(dpToPx(dm, 24), dpToPx(dm, 32), dpToPx(dm, 24), dpToPx(dm, 20))
                }

                val imgName = when (prayerName) {
                    "الفجر"   -> "ic_fajr"
                    "الظهر"   -> "ic_dhuhr"
                    "الجمعة" -> "ic_jumuah_prayer"
                    "العصر"   -> "ic_asr"
                    "المغرب" -> "ic_maghrib"
                    "العشاء" -> "ic_isha"
                    else     -> "ic_fajr"
                }
                val iconView = android.widget.ImageView(context).apply {
                    try {
                        val id = context.resources.getIdentifier(imgName, "drawable", context.packageName)
                        if (id != 0) setImageResource(id)
                    } catch (_: Exception) {}
                    val sz = dpToPx(dm, 92)
                    layoutParams = android.widget.LinearLayout.LayoutParams(sz, sz).apply {
                        gravity = Gravity.CENTER
                        bottomMargin = dpToPx(dm, 14)
                    }
                }

                val subtitleView = android.widget.TextView(context).apply {
                    text = "تنبيه قبل الأذان"
                    textSize = 14f; gravity = Gravity.CENTER
                    setTextColor(subColor)
                    setPadding(0, 0, 0, dpToPx(dm, 4))
                }

                val prayerNameView = android.widget.TextView(context).apply {
                    text = "صلاة $prayerName"
                    textSize = 28f; gravity = Gravity.CENTER
                    setTextColor(goldColor)
                    typeface = android.graphics.Typeface.DEFAULT_BOLD
                    setPadding(0, 0, 0, dpToPx(dm, 8))
                }

                val timeView = android.widget.TextView(context).apply {
                    text = "باقي $minutesBefore دقيقة على موعد الأذان"
                    textSize = 16f; gravity = Gravity.CENTER
                    setTextColor(Color.WHITE)
                    typeface = android.graphics.Typeface.DEFAULT_BOLD
                    setPadding(0, 0, 0, dpToPx(dm, 16))
                }

                centerContent.addView(iconView)
                centerContent.addView(subtitleView)
                centerContent.addView(prayerNameView)
                centerContent.addView(timeView)

                val centerParams = android.widget.FrameLayout.LayoutParams(
                    android.widget.FrameLayout.LayoutParams.MATCH_PARENT,
                    android.widget.FrameLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    gravity = Gravity.CENTER
                }
                visualsLayout.addView(centerContent, centerParams)

                // ── 2. Controls View (Bottom, Intercepts Touches) ──────────────────────────────
                val controlsLayout = android.widget.LinearLayout(context).apply {
                    orientation = android.widget.LinearLayout.VERTICAL
                    gravity = Gravity.CENTER_HORIZONTAL
                    setBackgroundColor(Color.TRANSPARENT)
                    setPadding(dpToPx(dm, 20), 0, dpToPx(dm, 20), dpToPx(dm, 36))
                }

                val dismissBtn = buildFullWidthButton(
                    context, "تم — جزاك الله خيراً", goldDark, Color.WHITE, 16f, 0, 26f
                )
                dismissBtn.setOnClickListener { dismiss(context) }
                controlsLayout.addView(dismissBtn)

                val lType = overlayLayerType()

                val visFlags = WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                        WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS

                val visParams = WindowManager.LayoutParams(
                    WindowManager.LayoutParams.MATCH_PARENT,
                    WindowManager.LayoutParams.MATCH_PARENT,
                    lType, visFlags, PixelFormat.TRANSLUCENT
                ).apply {
                    gravity = Gravity.FILL
                }

                wm.addView(visualsLayout, visParams)
                visualsView = visualsLayout

                val ctrlFlags = WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                        WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE

                val ctrlParams = WindowManager.LayoutParams(
                    WindowManager.LayoutParams.MATCH_PARENT,
                    WindowManager.LayoutParams.WRAP_CONTENT,
                    lType, ctrlFlags, PixelFormat.TRANSLUCENT
                ).apply {
                    gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
                }

                wm.addView(controlsLayout, ctrlParams)
                controlsView = controlsLayout

                NativeLogger.log(context, "PreAdhan overlay shown for $prayerName (${minutesBefore}min before)")
            } catch (e: Exception) {
                e.printStackTrace()
                NativeLogger.log(context, "PreAdhan overlay ERROR: ${e.message}")
            }
        }
    }

    // ─── Show Main Overlay ────────────────────────────────────────────────────

    fun show(context: Context, prayerName: String, alarmId: Int, isPreview: Boolean = false) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        if (!isPreview && !prefs.getBoolean("flutter.prayer_focus_enabled", false)) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            !android.provider.Settings.canDrawOverlays(context)) return

        if (!isPreview) {
            val dayStr = resolveIslamicDay(prefs)
            val logKey = "flutter.prayer_focus_log_$dayStr"
            val logStr = prefs.getString(logKey, null) ?: prefs.getString("prayer_focus_log_$dayStr", null)
            if (logStr != null) {
                try {
                    val logMap = JSONObject(logStr)
                    if (isPrayerLogged(logMap, prayerName)) {
                        NativeLogger.log(context, "PrayerFocus: $prayerName already prayed for $dayStr, aborting show.")
                        return
                    }
                } catch (_: Exception) {}
            }
        }

        dismiss(context)

        Handler(Looper.getMainLooper()).post {
            try {
                val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
                val dm = context.resources.displayMetrics
                val goldColor  = 0xFFE2BA84.toInt()
                val goldDark   = 0xFF9E6E2E.toInt()
                val subColor   = 0xFFCCCCCC.toInt()
                val snoozeBg   = 0x33D0A871.toInt()
                val snoozeText = 0xFFE2BA84.toInt()
                val backdropBg = Color.argb(195, 12, 10, 8) // Full screen dark tint

                // ── 1. Visuals View (Full-Screen, Touch-Passthrough) ──────────────────────────
                val visualsLayout = android.widget.FrameLayout(context).apply {
                    setBackgroundColor(backdropBg)
                }

                val centerContent = android.widget.LinearLayout(context).apply {
                    orientation = android.widget.LinearLayout.VERTICAL
                    gravity = Gravity.CENTER_HORIZONTAL
                    setPadding(dpToPx(dm, 24), dpToPx(dm, 20), dpToPx(dm, 24), dpToPx(dm, 20))
                }

                val imageName = when {
                    alarmId == 100 || alarmId == 110 || alarmId == 3000 || alarmId == 5000 -> "ic_fajr"
                    alarmId == 101 || alarmId == 3001 || alarmId == 5001 ->
                        if (Calendar.getInstance().get(Calendar.DAY_OF_WEEK) == Calendar.FRIDAY) "ic_jumuah_prayer" else "ic_dhuhr"
                    alarmId == 102 || alarmId == 3002 || alarmId == 5002 -> "ic_asr"
                    alarmId == 103 || alarmId == 3003 || alarmId == 5003 -> "ic_maghrib"
                    alarmId == 104 || alarmId == 3004 || alarmId == 5004 -> "ic_isha"
                    prayerName == "الفجر" -> "ic_fajr"
                    prayerName == "الظهر" -> "ic_dhuhr"
                    prayerName == "الجمعة" -> "ic_jumuah_prayer"
                    prayerName == "العصر" -> "ic_asr"
                    prayerName == "المغرب" -> "ic_maghrib"
                    prayerName == "العشاء" -> "ic_isha"
                    else -> "logo"
                }

                val iconView = android.widget.ImageView(context).apply {
                    try {
                        val resId = context.resources.getIdentifier(imageName, "drawable", context.packageName)
                        if (resId != 0) setImageResource(resId)
                    } catch (_: Exception) {}
                    val size = dpToPx(dm, 96)
                    layoutParams = android.widget.LinearLayout.LayoutParams(size, size).apply {
                        gravity = Gravity.CENTER
                        bottomMargin = dpToPx(dm, 10)
                    }
                }

                val subtitleView = android.widget.TextView(context).apply {
                    text = "حان وقت الصلاة"
                    textSize = 14f; gravity = Gravity.CENTER
                    setTextColor(subColor)
                    setPadding(0, dpToPx(dm, 4), 0, dpToPx(dm, 2))
                }

                val prayerNameView = android.widget.TextView(context).apply {
                    text = "صلاة $prayerName"
                    textSize = 28f; gravity = Gravity.CENTER
                    setTextColor(goldColor)
                    typeface = android.graphics.Typeface.DEFAULT_BOLD
                    setPadding(0, 0, 0, dpToPx(dm, 6))
                }

                val prayerStreak = recalculateTrueStreak(context)
                val streakContainer = android.widget.LinearLayout(context).apply {
                    orientation = android.widget.LinearLayout.HORIZONTAL
                    gravity = Gravity.CENTER
                    background = android.graphics.drawable.GradientDrawable().apply {
                        setColor(0x30E2BA84.toInt())
                        cornerRadius = 14f * dm.density
                    }
                    setPadding(dpToPx(dm, 16), dpToPx(dm, 6), dpToPx(dm, 16), dpToPx(dm, 6))
                    layoutParams = android.widget.LinearLayout.LayoutParams(
                        android.widget.LinearLayout.LayoutParams.WRAP_CONTENT,
                        android.widget.LinearLayout.LayoutParams.WRAP_CONTENT
                    ).apply {
                        bottomMargin = dpToPx(dm, 16)
                    }
                }

                val streakView = android.widget.TextView(context).apply {
                    text = if (prayerStreak > 0) "🔥 $prayerStreak صلاة متتالية" else "ابدأ سلسلة الصلاة اليوم"
                    textSize = 14f; gravity = Gravity.CENTER
                    setTextColor(if (prayerStreak > 0) 0xFFFFB300.toInt() else goldColor)
                    typeface = android.graphics.Typeface.DEFAULT_BOLD
                }
                streakContainer.addView(streakView)

                // ── Live Countdown & Progress Bar ──────────────────────────────────────────
                val timerContainer = android.widget.LinearLayout(context).apply {
                    orientation = android.widget.LinearLayout.VERTICAL
                    setPadding(dpToPx(dm, 16), dpToPx(dm, 12), dpToPx(dm, 16), dpToPx(dm, 14))
                    background = android.graphics.drawable.GradientDrawable().apply {
                        setColor(0x22FFFFFF.toInt())
                        cornerRadius = 16f * dm.density
                    }
                    layoutParams = android.widget.LinearLayout.LayoutParams(
                        android.widget.LinearLayout.LayoutParams.MATCH_PARENT,
                        android.widget.LinearLayout.LayoutParams.WRAP_CONTENT
                    ).apply {
                        bottomMargin = dpToPx(dm, 10)
                    }
                }

                val countdownView = android.widget.TextView(context).apply {
                    text = "جاري حساب الوقت..."
                    textSize = 14f; gravity = Gravity.CENTER
                    setTextColor(goldColor)
                    typeface = android.graphics.Typeface.DEFAULT_BOLD
                    setPadding(0, 0, 0, dpToPx(dm, 8))
                }

                val progressBar = android.widget.ProgressBar(context, null, android.R.attr.progressBarStyleHorizontal).apply {
                    isIndeterminate = false
                    progress = 0
                    max = 100
                    val h = dpToPx(dm, 8)
                    layoutParams = android.widget.LinearLayout.LayoutParams(
                        android.widget.LinearLayout.LayoutParams.MATCH_PARENT, h
                    )
                    val bgDrawable = android.graphics.drawable.GradientDrawable().apply {
                        setColor(0x33FFFFFF.toInt())
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

                centerContent.addView(iconView)
                centerContent.addView(subtitleView)
                centerContent.addView(prayerNameView)
                centerContent.addView(streakContainer)
                centerContent.addView(timerContainer)

                val centerParams = android.widget.FrameLayout.LayoutParams(
                    android.widget.FrameLayout.LayoutParams.MATCH_PARENT,
                    android.widget.FrameLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    gravity = Gravity.CENTER
                    setMargins(dpToPx(dm, 20), 0, dpToPx(dm, 20), dpToPx(dm, 70))
                }
                visualsLayout.addView(centerContent, centerParams)

                // ── Precise Live Countdown Calculation ──────────────────────────────────────
                val prayerWindow = calculatePrayerWindow(context, prayerName)
                val totalDuration = (prayerWindow.targetEpoch - prayerWindow.startEpoch).coerceAtLeast(1L)

                liveTimer?.cancel()
                val timeRemaining = prayerWindow.targetEpoch - System.currentTimeMillis()
                if (timeRemaining > 0) {
                    liveTimer = object : CountDownTimer(timeRemaining, 1000L) {
                        override fun onTick(millisUntilFinished: Long) {
                            val hrs = millisUntilFinished / (3600 * 1000L)
                            val mins = (millisUntilFinished % (3600 * 1000L)) / (60 * 1000L)
                            val secs = (millisUntilFinished % (60 * 1000L)) / 1000L

                            countdownView.text = "متبقي على صلاة ${prayerWindow.nextName}: ${hrs}س ${mins}د ${secs}ث"

                            val elapsed = (System.currentTimeMillis() - prayerWindow.startEpoch).coerceIn(0L, totalDuration)
                            val percent = ((elapsed.toDouble() / totalDuration) * 100).toInt().coerceIn(0, 100)
                            progressBar.progress = percent
                        }

                        override fun onFinish() {
                            countdownView.text = "حان وقت صلاة ${prayerWindow.nextName}"
                            progressBar.progress = 100
                        }
                    }.start()
                } else {
                    countdownView.text = "حان وقت صلاة ${prayerWindow.nextName}"
                    progressBar.progress = 100
                }

                // ── 2. Controls View (Bottom, Intercepts Touches) ──────────────────────────────
                val controlsLayout = android.widget.LinearLayout(context).apply {
                    orientation = android.widget.LinearLayout.VERTICAL
                    gravity = Gravity.CENTER_HORIZONTAL
                    setBackgroundColor(Color.TRANSPARENT)
                    setPadding(dpToPx(dm, 20), 0, dpToPx(dm, 20), dpToPx(dm, 32))
                }

                val prayedButton = buildFullWidthButton(
                    context, "صليتُ والله ✓", goldDark, Color.WHITE, 17f, dpToPx(dm, 12), 26f
                )

                val snoozeMins = try {
                    val bits = prefs.getLong("flutter.focus_snooze_duration", -1L)
                    if (bits != -1L) bits.toInt().coerceIn(1, 60) else prefs.getInt("flutter.focus_snooze_duration", 5).coerceIn(1, 60)
                } catch (_: Exception) { 5 }

                val snoozeButton = buildFullWidthButton(
                    context, "ذكرني بعد $snoozeMins دقائق (5)",
                    snoozeBg, snoozeText, 14f, 0, 26f
                )
                snoozeButton.isEnabled = false
                snoozeButton.alpha = 0.5f

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
                    if (isPreview) {
                        dismiss(context)
                    } else {
                        onSnooze(context, prayerName, alarmId, snoozeMins)
                    }
                }

                prayedButton.setOnClickListener {
                    countdownHandler.removeCallbacks(countdownRunnable)
                    showConfirmationButtons(context, controlsLayout, prayedButton, snoozeButton, prayerName, alarmId,
                        goldColor, goldDark, subColor, isPreview)
                }

                controlsLayout.addView(prayedButton)
                controlsLayout.addView(snoozeButton)

                val lType = overlayLayerType()

                val visFlags = WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                        WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS

                val visParams = WindowManager.LayoutParams(
                    WindowManager.LayoutParams.MATCH_PARENT,
                    WindowManager.LayoutParams.MATCH_PARENT,
                    lType, visFlags, PixelFormat.TRANSLUCENT
                ).apply {
                    gravity = Gravity.FILL
                }

                wm.addView(visualsLayout, visParams)
                visualsView = visualsLayout

                val ctrlFlags = WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                        WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE

                val ctrlParams = WindowManager.LayoutParams(
                    WindowManager.LayoutParams.MATCH_PARENT,
                    WindowManager.LayoutParams.WRAP_CONTENT,
                    lType, ctrlFlags, PixelFormat.TRANSLUCENT
                ).apply {
                    gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
                }

                wm.addView(controlsLayout, ctrlParams)
                controlsView = controlsLayout

                NativeLogger.log(context, "PrayerFocusOverlay shown for $prayerName (id: $alarmId, isPreview: $isPreview)")
            } catch (e: Exception) {
                e.printStackTrace()
                NativeLogger.log(context, "PrayerFocusOverlay ERROR: ${e.message}")
            }
        }
    }

    private fun calculatePrayerWindow(context: Context, currentPrayerName: String): PrayerWindow {
        val now = System.currentTimeMillis()
        var start = now
        var target = now + 3 * 3600 * 1000L + 30 * 60 * 1000L
        var nextName = when (currentPrayerName) {
            "الفجر" -> "الظهر"
            "الظهر", "الجمعة" -> "العصر"
            "العصر" -> "المغرب"
            "المغرب" -> "العشاء"
            "العشاء" -> "الفجر"
            else -> "الصلاة القادمة"
        }

        try {
            val ptToday = NativePrayerManager.calculatePrayerTimes(context, Date(now))
            val ptTomorrow = NativePrayerManager.calculatePrayerTimes(context, Date(now + 86400000L))
            if (ptToday != null) {
                when (currentPrayerName) {
                    "الفجر" -> {
                        start = ptToday.fajr.time
                        target = ptToday.dhuhr.time
                        nextName = "الظهر"
                    }
                    "الظهر", "الجمعة" -> {
                        start = ptToday.dhuhr.time
                        target = ptToday.asr.time
                        nextName = "العصر"
                    }
                    "العصر" -> {
                        start = ptToday.asr.time
                        target = ptToday.maghrib.time
                        nextName = "المغرب"
                    }
                    "المغرب" -> {
                        start = ptToday.maghrib.time
                        target = ptToday.isha.time
                        nextName = "العشاء"
                    }
                    "العشاء" -> {
                        start = ptToday.isha.time
                        target = ptTomorrow?.fajr?.time ?: (ptToday.isha.time + 8 * 3600 * 1000L)
                        nextName = "الفجر"
                    }
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        if (target <= now) {
            target = now + 3600 * 1000L
        }

        return PrayerWindow(currentPrayerName, nextName, start, target)
    }

    data class PrayerWindow(
        val currentName: String,
        val nextName: String,
        val startEpoch: Long,
        val targetEpoch: Long
    )

    private fun showConfirmationButtons(
        context: Context,
        controlsLayout: android.widget.LinearLayout,
        prayedButton: android.widget.Button,
        snoozeButton: android.widget.Button,
        prayerName: String,
        alarmId: Int,
        goldColor: Int,
        goldDark: Int,
        subColor: Int,
        isPreview: Boolean
    ) {
        prayedButton.visibility = View.GONE
        snoozeButton.visibility = View.GONE
        val dm = context.resources.displayMetrics

        val confirmLabel = android.widget.TextView(context).apply {
            text = "هل كانت في وقتها؟"
            textSize = 15f; gravity = Gravity.CENTER
            setTextColor(subColor)
            setPadding(0, 0, 0, dpToPx(dm, 12))
        }

        val row = android.widget.LinearLayout(context).apply {
            orientation = android.widget.LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 0)
        }

        val onTimeBtn = buildHalfButton(context, "في وقتها ✓", 0xFF2E7D32.toInt(), Color.WHITE, 15f)
        val lateBtn   = buildHalfButton(context, "متأخراً  ⏳", 0xFFD84315.toInt(), Color.WHITE, 15f)

        val halfP1 = android.widget.LinearLayout.LayoutParams(0, android.widget.LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            .apply { setMargins(0, 0, dpToPx(dm, 6), 0) }
        val halfP2 = android.widget.LinearLayout.LayoutParams(0, android.widget.LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            .apply { setMargins(dpToPx(dm, 6), 0, 0, 0) }

        onTimeBtn.layoutParams = halfP1
        lateBtn.layoutParams   = halfP2

        onTimeBtn.setOnClickListener { onPrayed(context, prayerName, alarmId, isOnTime = true, goldColor = goldColor, isPreview = isPreview) }
        lateBtn.setOnClickListener   { onPrayed(context, prayerName, alarmId, isOnTime = false, goldColor = goldColor, isPreview = isPreview) }

        row.addView(onTimeBtn)
        row.addView(lateBtn)

        val prayedIndex = controlsLayout.indexOfChild(prayedButton)
        controlsLayout.addView(confirmLabel, prayedIndex + 1)
        controlsLayout.addView(row, prayedIndex + 2)
    }

    private fun onPrayed(
        context: Context,
        prayerName: String,
        alarmId: Int,
        isOnTime: Boolean,
        goldColor: Int,
        isPreview: Boolean
    ) {
        cancelSnooze(context)
        val newStreak = if (!isPreview) {
            markPrayerInAccountability(context, prayerName)
            savePrayerLog(context, prayerName, if (isOnTime) "ontime" else "late")
            recalculateTrueStreak(context)
        } else {
            recalculateTrueStreak(context).coerceAtLeast(1)
        }
        NativeLogger.log(context, "PrayerFocus: $prayerName ✓ onTime=$isOnTime streak=$newStreak isPreview=$isPreview")

        showAchievementScreen(context, prayerName, newStreak, goldColor)
    }

    private fun showAchievementScreen(
        context: Context,
        prayerName: String,
        streak: Int,
        goldColor: Int
    ) {
        val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        
        dismiss(context)
        cancelSnooze(context)
        
        val dm = context.resources.displayMetrics
        val goldDark = 0xFF9E6E2E.toInt()
        val backdropBg = Color.argb(210, 12, 10, 8)

        val root = android.widget.FrameLayout(context).apply {
            setBackgroundColor(backdropBg)
        }

        val card = android.widget.LinearLayout(context).apply {
            orientation = android.widget.LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            background = android.graphics.drawable.GradientDrawable().apply {
                setColor(0xEE1E1C1A.toInt())
                cornerRadius = 28f * dm.density
            }
            setPadding(dpToPx(dm, 24), dpToPx(dm, 28), dpToPx(dm, 24), dpToPx(dm, 28))
        }

        val titleView = android.widget.TextView(context).apply {
            text = "الحمد لله!"
            textSize = 28f; gravity = Gravity.CENTER
            setTextColor(goldColor)
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            setPadding(0, dpToPx(dm, 8), 0, dpToPx(dm, 4))
        }

        val descView = android.widget.TextView(context).apply {
            text = "أتممت صلاة $prayerName تقبل الله منا ومنكم صالح الأعمال"
            textSize = 14f; gravity = Gravity.CENTER
            setTextColor(Color.WHITE)
            setPadding(0, 0, 0, dpToPx(dm, 16))
        }

        val streakCard = android.widget.LinearLayout(context).apply {
            orientation = android.widget.LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dpToPx(dm, 16), dpToPx(dm, 12), dpToPx(dm, 16), dpToPx(dm, 16))
            background = android.graphics.drawable.GradientDrawable().apply {
                setColor(0x33D0A871.toInt())
                cornerRadius = 16f * dm.density
            }
        }

        val streakNum = android.widget.TextView(context).apply {
            text = "🔥 $streak"
            textSize = 38f; gravity = Gravity.CENTER
            setTextColor(0xFFFFB300.toInt())
            typeface = android.graphics.Typeface.DEFAULT_BOLD
        }

        val streakLabel = android.widget.TextView(context).apply {
            text = "صلوات متتالية دون انقطاع"
            textSize = 14f; gravity = Gravity.CENTER
            setTextColor(Color.WHITE)
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

        val continueBtn = buildFullWidthButton(
            context, "متابعة", goldDark, Color.WHITE, 16f, 0, 26f
        )
        continueBtn.setOnClickListener { 
            cancelSnooze(context)
            dismiss(context) 
        }

        card.addView(titleView)
        card.addView(descView)
        card.addView(streakCard)
        card.addView(continueBtn)

        val cardParams = android.widget.FrameLayout.LayoutParams(
            android.widget.FrameLayout.LayoutParams.MATCH_PARENT,
            android.widget.FrameLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            gravity = Gravity.CENTER
            setMargins(dpToPx(dm, 24), 0, dpToPx(dm, 24), 0)
        }
        root.addView(card, cardParams)
        
        val lType = overlayLayerType()
        
        val flags = WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or 
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            lType, flags, PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.FILL
        }
        
        wm.addView(root, params)
        visualsView = root
    }

    private fun onSnooze(context: Context, prayerName: String, alarmId: Int, snoozeMinsParam: Int? = null) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val snoozeMins = snoozeMinsParam ?: try {
            val raw = prefs.all["flutter.focus_snooze_duration"]
            when (raw) {
                is Long -> raw.toInt().coerceIn(1, 60)
                is Int -> raw.coerceIn(1, 60)
                is Double -> raw.toInt().coerceIn(1, 60)
                is String -> raw.toIntOrNull()?.coerceIn(1, 60) ?: 5
                else -> 5
            }
        } catch (_: Exception) { 5 }

        dismiss(context)
        cancelSnooze(context)
        NativeLogger.log(context, "PrayerFocus: Snoozed $prayerName for $snoozeMins min")

        // 1. AlarmManager exact wakeup alarm (breaks through Doze mode & screen off)
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            putExtra("is_snooze_overlay", true)
            putExtra("payload", "snooze_focus_overlay")
            putExtra("snooze_prayer_name", prayerName)
            putExtra("snooze_alarm_id", alarmId)
            putExtra("alarm_id", 8888)
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            8888,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val triggerAtMillis = System.currentTimeMillis() + (snoozeMins * 60 * 1000L)
        if (alarmManager != null) {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
                } else {
                    alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
                }
            } catch (e: Exception) {
                NativeLogger.log(context, "PrayerFocus: Failed to schedule exact snooze AlarmManager: ${e.message}")
            }
        }

        // 2. Active in-memory handler fallback
        val h = Handler(Looper.getMainLooper())
        val r = Runnable { show(context, prayerName, alarmId) }
        snoozeHandler = h
        snoozeRunnable = r
        h.postDelayed(r, snoozeMins * 60 * 1000L)
    }

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
        val cal = Calendar.getInstance()
        val todayStr = sdf.format(Date(now))

        val fajrKey = "flutter.fajr_epoch_today"
        val fajrEpoch = try {
            val raw = prefs.all[fajrKey]
            (raw as? Number)?.toLong() ?: raw?.toString()?.toLongOrNull() ?: -1L
        } catch (_: Exception) { -1L }

        if (fajrEpoch > 0 && now < fajrEpoch) {
            cal.timeInMillis = now
            cal.add(Calendar.DAY_OF_YEAR, -1)
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

    fun getPrayerStreak(context: Context, prayerName: String): Int {
        return recalculateTrueStreak(context)
    }

    private fun isPrayerLogged(map: JSONObject, k: String): Boolean {
        var obj: Any? = if (map.has(k)) map.opt(k) else null
        if (obj == null || obj == false) {
            if (k == "الظهر" && map.has("الجمعة")) {
                obj = map.opt("الجمعة")
            } else if (k == "الجمعة" && map.has("الظهر")) {
                obj = map.opt("الظهر")
            }
        }
        if (obj == null || obj == false) return false
        if (obj is Boolean) return obj
        if (obj is String) return obj.isNotEmpty()
        if (obj is JSONObject) {
            val s = obj.optString("status", "")
            return s.isNotEmpty()
        }
        return true
    }

    private fun recalculateTrueStreak(context: Context): Int {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val sdf = SimpleDateFormat("yyyy-MM-dd", Locale.US)
        var streak = 0
        var shouldContinue = true

        for (dayOffset in 0..730) {
            if (!shouldContinue) break
            val cal = Calendar.getInstance()
            cal.add(Calendar.DAY_OF_YEAR, -dayOffset)
            val dateStr = sdf.format(cal.time)
            val raw = prefs.getString("flutter.prayer_focus_log_$dateStr", null)
                ?: prefs.getString("prayer_focus_log_$dateStr", null)
            val map = if (raw != null) try { JSONObject(raw) } catch (_: Exception) { JSONObject() } else JSONObject()

            val isFriday = cal.get(Calendar.DAY_OF_WEEK) == Calendar.FRIDAY
            val prayersInReverse = listOf("العشاء", "المغرب", "العصر", if (isFriday) "الجمعة" else "الظهر", "الفجر")

            if (dayOffset == 0) {
                var foundLatest = false
                for (k in prayersInReverse) {
                    val isLogged = isPrayerLogged(map, k)
                    if (isLogged) {
                        foundLatest = true
                        streak++
                    } else if (foundLatest) {
                        shouldContinue = false
                        break
                    }
                }
            } else {
                for (k in prayersInReverse) {
                    val isLogged = isPrayerLogged(map, k)
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

    private fun overlayLayerType(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        else
            @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE
    }

    private fun dpToPx(dm: android.util.DisplayMetrics, dp: Int): Int {
        return (dp * dm.density).toInt()
    }

    private fun buildFullWidthButton(
        context: Context,
        text: String,
        bgColor: Int,
        textColor: Int,
        textSizeSp: Float,
        marginBottom: Int,
        cornerRadiusDp: Float = 26f
    ): android.widget.Button {
        val dm = context.resources.displayMetrics
        val bg = android.graphics.drawable.GradientDrawable().apply {
            setColor(bgColor)
            cornerRadius = cornerRadiusDp * dm.density
        }
        val paddingH = dpToPx(dm, 20)
        val paddingV = dpToPx(dm, 15)
        val btn = android.widget.Button(context).apply {
            this.text = text
            this.textSize = textSizeSp
            setTextColor(textColor)
            background = bg
            setPadding(paddingH, paddingV, paddingH, paddingV)
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            isAllCaps = false
        }
        btn.layoutParams = android.widget.LinearLayout.LayoutParams(
            android.widget.LinearLayout.LayoutParams.MATCH_PARENT,
            android.widget.LinearLayout.LayoutParams.WRAP_CONTENT
        ).also { it.setMargins(0, 0, 0, marginBottom) }
        return btn
    }

    private fun buildHalfButton(
        context: Context,
        text: String,
        bgColor: Int,
        textColor: Int,
        textSizeSp: Float,
        cornerRadiusDp: Float = 22f
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
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            isAllCaps = false
        }
    }
}
