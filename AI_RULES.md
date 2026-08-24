# Ibad Al-Rahmann - AI Constraints & Rules
1. **Overlay (Native Kotlin)**: Uses Split-Window Hack.
   - Visuals View: Full-screen `MATCH_PARENT` x `MATCH_PARENT` dark backdrop `Color.argb(195, 12, 10, 8)` with `FLAG_NOT_TOUCHABLE | FLAG_NOT_FOCUSABLE`. All touches pass right through to background apps.
   - Controls View: Bottom aligned `MATCH_PARENT` x `WRAP_CONTENT` with `background = null` (100% transparent root, NO dark card around buttons!). `FLAG_NOT_TOUCH_MODAL | FLAG_NOT_FOCUSABLE`. Buttons span the full width at the bottom of the screen.
   - Countdown Timer: Live real second-by-second countdown to the NEXT prayer in the current prayer interval (Fajr -> Dhuhr, Dhuhr -> Asr, Asr -> Maghrib, Maghrib -> Isha, Isha -> Fajr) with animated progress percentage.
   - Preview Parity: Preview mode (`showFocusOverlayPreview`) MUST trigger the exact same native Kotlin overlay as the live alarm overlay. DO NOT use Flutter `showDialog` or `PrayerAlertModal` for the overlay preview.
2. **Persistent Notification & Shade Ranking**:
   - Persistent Notification (`PrayerNotificationService`) MUST stay at the VERY TOP of the notification shade above all other app notifications (`IMPORTANCE_MAX`, `PRIORITY_MAX`, `.setOngoing(true)`, `.setSortKey("0000_top")`).
   - Other app notifications (Adhan, Pre-Adhan, Iqama, Azkar, Wird) use `IMPORTANCE_HIGH` / `PRIORITY_HIGH` so they rank below the persistent notification.
   - When persistent notification is disabled (`STOP_PRAYER_NOTIFICATION` or `!isPersistentNotificationEnabled()`), `PrayerNotificationService` MUST cancel notification ID 777 immediately and call `stopSelf()`, NEVER posting a dummy "جاري التحديث..." notification.
3. **Hijri Dates & Manual/Local Offsets (Kotlin & Widgets)**:
   - Primary source: ICU Umm al-Qura calculation `android.icu.util.IslamicCalendar.CalculationType.ISLAMIC_UMALQURA` combined with `flutter.hijri_offset_manual`, `flutter.hijri_local_delta`, and `flutter.hijri_offset`.
   - Supports user manual adjustment (e.g. Day 29/30 local moon sighting in Egypt or other countries) and synchronizes immediately with persistent notification and all home widgets.
   - Maghrib Day Transition: In Islamic law, the new day starts at Maghrib (sunset). If current time is after today's Maghrib, the date MUST advance to the next Islamic day.
   - Never return stale daytime strings from `HomeWidgetPreferences` when the day has advanced.
4. **Snooze Logic**: Calculate target time strictly using the exact tap moment (`DateTime.now().add(...)`), NOT a cached build time.
5. **DO NOT DELETE**: Never delete existing AlarmManager/WorkManager tasks when updating UI or unrelated logic.
6. **Quran Page & Wird Export**: MUST render exactly identical to the standard Mushaf page (`WbwPageWidget`). NEVER use `MainAxisSize.min`, custom font shrinking, aspect-ratio hacks, or remove `Expanded` lines during export. All 15 lines and header/footer must maintain standard page layout and spacing without squishing lines together or creating dead space.
7. **Home Prayer Ring & Texts**: Circular countdown and prayer name texts inside the ring MUST have generous margins (`FittedBox` + horizontal padding `28.w`) and inner diameter (`230.w`) so text never touches or clips the outer ring border on any screen resolution.
8. **Qiyam al-Layl Preference Synchronization**: Always synchronize `adhan_mode_Last_third`, `qiyam_mode_notif`, and `notif_qiyam` across `alarms_screen.dart`, `prayer_times_screen.dart`, and `prayer_detail_modal.dart` whenever Qiyam settings are read or written.
9. **Accountability (حاسب نفسك) Customization**: Sections MUST support adding/deleting custom goals/items via `custom_items_$key` and `deleted_items_$key` in SharedPreferences with instant calculation of daily completion percentages.
10. **Flip-to-Mute (كتم الأذان بالقلب)**: The Adhan MUST ring even if the device was already face-down before the alarm fired (`wasFaceUp = false` on start). Mute only triggers after the phone transitions from Face-Up (`z > 3.0f`) to true Flat Face-Down (`z < -8.0f && |x| < 3.5f && |y| < 3.5f`), preventing false triggers while resting in pockets or held vertically.
11. **Ramadan Qadaa (قضاء رمضان)**: Ramadan missed fasts belong to the preceding Ramadan year (`hMonth >= 9 ? hYear : hYear - 1`) and MUST remain active, unlocked, and editable through all 12 months until the 1st of the upcoming Ramadan (`1 Ramadan`, month 9) arrives.
12. **System Status Bar Visibility**: The system status bar (شريط الإشعارات العلوي) MUST be visible across the entire application (`SystemUiMode.manual, overlays: SystemUiOverlay.values`). DO NOT touch or alter the fullscreen / immersive mode inside Quran reading views (المصحف العادي، مصحف الورد، مصحف الكهف).
13. **Support & Diagnostics Section**:
    - "سجل الإشعارات" (Notification Logging Switch + View Log) and "تشخيص دقة أوقات الصلاة" belong strictly in the "الدعم" (Support) section of Settings.
    - "تشخيص دقة أوقات الصلاة" MUST display the exact time and date of the last GPS update (e.g. `22/08/2026 الساعة 08:30:15 م`).
14. **Clean Migration & State Reset on App Update**:
    - `AppMigrationHelper` (Dart) and `AppMigrationManager` (Kotlin) execute on startup whenever `version_code` increases.
    - Purges obsolete notification channels (`persistent_prayer_v1`..`v22`, `prayer_sound_channel_v1`..`v12`, etc.), cancels stale AlarmManager alarms, clears old cached epochs, and regenerates fresh 30-day prayer times cleanly without wiping user bookmarks, khatmas, or custom goals.
15. **Strict Silence & Disabled State Enforcement**:
    - If any prayer, azkar, wird, or reminder is disabled or set to "none" in settings: it MUST NEVER send a notification or play audio (`AlarmReceiver.kt` and `PrayerNotificationService.kt` abort immediately).
    - If sound is set to "صامت" / `silent_notif` / `silent`: post purely visual notifications, never playing audio.
    - If device is in Silent mode (`RINGER_MODE_SILENT`) or Vibrate mode (`RINGER_MODE_VIBRATE`): `AudioVibrationManager` MUST return `false` and NEVER play audio.
16. **Zero Startup Latency for Prayer Times**:
    - `PrayerService` MUST initialize cached coordinates and settings synchronously from `CacheHelper.prefs` on constructor instantiation so `getPrayerTimes()` immediately returns valid prayer times on frame 0 with 0ms delay.
    - NEVER introduce artificial delays before initializing `PrayerService`.
17. **Backup File Naming & Extension Protection (النسخ الاحتياطي)**:
    - Never use a static filename (like `ibad_al_rahmann_backup.json`) when exporting or saving to device, as Android Storage Access Framework (SAF) appends numbering after the `.json` extension (e.g. `.json (1)`), breaking file format detection and rendering it unselectable.
    - Always use a timestamped filename: `ibad_al_rahmann_backup_${DateFormat('yyyy_MM_dd_HHmmss').format(now)}.json`.
    - `importBackup` MUST support fallback to `FileType.any` to gracefully open any previously saved or numbered backup files.
18. **Prayer & Azkar Streak Logic**:
    - Salati Streak: Unbounded consecutive calculation scanning all historical logs (no 30/60 day cap). Seamlessly synchronizes in-app logging, modal dialogs, and native overlay tracking.
    - Azkar Streak: 50% completion threshold of required session counts qualifies for streak. Per-item lifetime stats (`azkar_item_total_*`) preserved in backup.
19. **Screen Unlock Salawat Custom Audio & Volume Boost**:
    - Supports custom device audio path (`salah_unlock_custom_path`).
    - Temporarily boosts system audio stream volume during playback and automatically restores the original stream volume on completion/error.
20. **Mushaf Page Header & Smooth Gestures**:
    - Layout: Right side = Juz (with zero font clipping `height: 1.0`) & boundary-only Hizb/Quarter badge via `QuranHizbData.labelForPage(pageNumber)` (shown ONLY when a new Hizb, 1/4, 1/2, or 3/4 begins, empty on intermediate pages); Left side = Surah name(s) scaled with `FittedBox`.
    - Page navigation uses `ClampingScrollPhysics(parent: PageScrollPhysics())` without double-tap recognizer delay on PageView to guarantee instant zero-lag page turning.
21. **Exact Doze-Proof Snooze Wakeup (Configurable Duration)**:
    - Snoozing prayer overlay (`onSnooze`) MUST read the user-configured duration (`flutter.focus_snooze_duration`, e.g. 5, 10, 15 mins) and schedule an exact `AlarmManager.setExactAndAllowWhileIdle(RTC_WAKEUP, ...)` with PendingIntent to `AlarmReceiver.kt` so the snooze fires with 100% precision even when screen is turned off or deep sleep (Doze mode) is active.
22. **Hijri Day Transition at Maghrib (Sunset)**:
    - The Islamic day begins at Maghrib (sunset), not midnight.
    - If current time is after today's Maghrib time, the Hijri date must immediately advance to tomorrow's Islamic date across all widgets, notifications, and native calculations.
    - Native `getHijriDate` must compute dynamically via ICU `ISLAMIC_UMALQURA` and never return a stale daytime string from `HomeWidgetPreferences`.
23. **Native Android Splash Screen & Logo Parity**:
    - The native launch splash screen (before Flutter draws its first frame) MUST immediately display the app logo (`assets/images/logo.png`) centered on the splash background (white in light mode, `#121212` in dark mode) via `flutter_native_splash` on both Android 12+ (`android:windowSplashScreenAnimatedIcon`) and legacy Android (`@drawable/launch_background`).
    - The native splash screen MUST NOT be a plain empty white window.
24. **Khatma Notification Parity & Deduplication**:
    - Wird and Khatma notifications MUST always include the calculated page numbers (` (ص$startPage–$endPage)`).
    - Both Dart (`notification_service.dart`) and Kotlin (`NativeAzkarScheduler.kt`) MUST compute identical `idBase` via standardized string hash and never create disjoint or duplicate alarm IDs for the same Khatma.
25. **Dynamic Timestamped Log Export & Issue Reporting**:
    - App log exports and problem reports MUST use dynamic timestamped filenames (`ibad_app_log_${DateFormat('yyyy_MM_dd_HHmmss').format(now)}.txt`) and include full date-time strings (`yyyy-MM-dd HH:mm:ss.SSS`) with device/OS diagnostics.
26. **Fail-Safe Autonomous Hijri Date & Prayer Times (Zero-Open Resiliency)**:
    - Hijri date, prayer times, widgets, and persistent notifications MUST update autonomously and continuously even if the app remains unopened for multiple days or weeks.
    - Calculation hierarchy:
      1. Primary: Native ICU Umm al-Qura (`IslamicCalendar.CalculationType.ISLAMIC_UMALQURA`).
      2. Month transition validation: Auto-resets previous month's manual offset when the new Hijri month arrives.
      3. Fallback: Algorithmic Umm al-Qura calculation.
      4. Emergency fail-safe: Standard astronomical conversion with sunset (Maghrib) day advancement.
    - PrayerFocusOverlay MUST check `prayer_focus_log_${dayStr}` before displaying and abort immediately if the prayer is already logged, ensuring the overlay never re-appears after the user taps "صليت".
27. **True AMOLED Black & Pure White Theme Standard**:
    - In Dark Mode, background colors MUST prioritize pure/true black (`#000000` / `#0A0A0A` / `#121212`) for maximum AMOLED screen energy efficiency and deep contrast.
    - In Light Mode, backgrounds MUST be crisp clean white (`#FFFFFF`) with legible typography and golden Islamic accents (`#D0A871`).
28. **Quran Header Hizb Boundaries (3 Boundaries Per Hizb) & Header Typography**:
    - Hizb badges MUST appear strictly 3 times per Hizb (Start: `الحزب X`, Half: `نصف الحزب X`, Three-Quarters: `ثلاثة أرباع الحزب X`) on their exact boundary pages, and omitted on intermediate pages.
    - On boundary pages, the Hizb badge is placed to the left of the Juz number (in RTL header row), and the Juz number font size is scaled down proportionally (`isTablet ? 26 : 18`) to ensure balanced spacing across regular Mushaf, Wird Mushaf, and Surah Al-Kahf.
29. **Quran Double-Tap & Single-Tap Gesture Isolation (No-Hang Layout Switching)**:
    - Full Quran view (`full_quran_mobile.dart`) MUST use `_TapListener` to cleanly distinguish single-tap (toggle action bar overlay) from double-tap (`QuranCubit.changeLayout()`).
    - Double-tap MUST NEVER rapidly trigger and cancel the single-tap menu or freeze layout transitions.
30. **Fail-Safe Emergency Audio Muting & Boot Resilience**:
    - Muting audio via notification button ("إيقاف الصوت"), notification dismiss, or Flip-to-Mute MUST immediately stop and release all `MediaPlayer` instances, stop foreground audio services, restore saved system volume, and cancel notifications with 100% fail-safe reliability.
    - `BOOT_COMPLETED` receiver MUST run all scheduling asynchronously without blocking system boot or causing device UI stutter.
31. **Google Drive Clean Session Migration & Interactive Re-auth**:
    - On app version updates (`AppMigrationHelper`), cached Google Sign-In email and session tokens MUST be cleaned and disconnected to prevent ghost sessions or repeated account selection dialog loops.
    - Silent authentication timeout must be capped at 3 seconds, gracefully falling back to interactive authentication or notification prompting when backup/sync is requested.

