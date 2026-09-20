# Ibad Al-Rahmann - AI Constraints & Rules

## Core Guidelines & Safety
1. **Never Git Push**: NEVER execute `git push` under any circumstances unless explicitly commanded by the user.
2. **Consult Before Assuming**: If any requirement, bug cause, or design choice is uncertain or ambiguous, ALWAYS ask the user before writing speculative code.
3. **Surgical Changes & No Regressions**: Touch only what is strictly necessary. Never break, delete, or downgrade existing working features (Adhan downloads, Share Cards, Reciters, etc.).
4. **Zero UI Freezing (Non-Blocking Scheduling)**: All prayer scheduling, notification updates, and alarm refreshes MUST run asynchronously in a background non-blocking task (`scheduleToday`), never blocking the UI thread or freezing screens when popping.

---

## 1. Native Overlay (Kotlin Split-Window Hack)
- Visuals View: Full-screen `MATCH_PARENT` x `MATCH_PARENT` dark backdrop `Color.argb(195, 12, 10, 8)` with `FLAG_NOT_TOUCHABLE | FLAG_NOT_FOCUSABLE`. All touches pass right through to background apps.
- Controls View: Bottom aligned `MATCH_PARENT` x `WRAP_CONTENT` with `background = null` (100% transparent root, NO dark card around buttons!). `FLAG_NOT_TOUCH_MODAL | FLAG_NOT_FOCUSABLE`. Buttons span the full width at the bottom of the screen.
- Countdown Timer: Live real second-by-second countdown to the NEXT prayer with animated progress percentage.
- Preview Parity: Preview mode (`showFocusOverlayPreview`) MUST trigger the exact same native Kotlin overlay as the live alarm overlay.
- 10-Second Confirmation Delay: The "صليتُ والله ✓" button MUST enforce a 10-second countdown timer `(10)...(1)` before becoming enabled/clickable to prevent accidental taps.

## 2. Persistent Notification & Shade Ranking
- Persistent Notification (`PrayerNotificationService`) MUST stay at the VERY TOP of the notification shade above all other app notifications (`IMPORTANCE_MAX`, `PRIORITY_MAX`, `.setOngoing(true)`, `.setSortKey("0000_top")`).
- Other app notifications use `IMPORTANCE_HIGH` / `PRIORITY_HIGH` so they rank below the persistent notification.
- When persistent notification is disabled, cancel notification ID 777 immediately and call `stopSelf()`.

## 3. Hijri Dates & Maghrib Day Transition
- Primary source: ICU Umm al-Qura calculation combined with manual offsets.
- In Islamic law, the new day starts at Maghrib (sunset). If current time is after today's Maghrib, the date MUST advance to the next Islamic day across all widgets, notifications, and native calculations.

## 4. Quran Page Header & Layout Standard
- **Header Layout**:
  - **Right Side (in RTL)**: Juz number (`juz001` font) with proportional size (`isTablet ? 24 : 18`), and boundary-only Hizb/Quarter badge (via `QuranHizbData.labelForPage(pageNumber)`) placed beside it.
  - **Left Side (in RTL)**: Surah name(s) scaled with `FittedBox`.
  - **Container**: Contained in a dedicated row with symmetric horizontal padding (`isTablet ? 32 : 22` right, `isTablet ? 24 : 16` left), preventing Juz and Hizb from overlapping or touching outer screen edges.
- **Export & Page Rendering**: All 15 lines and header/footer must maintain standard page layout and spacing. NEVER use `MainAxisSize.min`, custom font shrinking, or aspect-ratio hacks during export.

## 5. Verse Player, Highlighting & Background Playback
- **Highlighting**: Active playing verse highlight MUST cover all word glyphs AND the end-of-ayah marker in clear vibrant gold (`Color(0xFFE5A93C).withValues(alpha: 0.45)` for light paper, `0.55` for dark paper). When word segments are available, the active word must highlight synchronously with audio in real-time.
- **Reciter Dropdown**: Contained inside `Flexible` with ellipsis so long names never clip to the right edge or push UI elements off-screen. Switching reciter in the dropdown must immediately reload audio and segment timing.
- **Continuous Auto-Play & Background**: When continuous mode is active, transitioning to the next verse MUST be asynchronous and seamless, advance the verse, and automatically turn the Quran page when crossing page boundaries. Audio MUST continue playing when the screen is locked and support headset / lockscreen media controls via `JustAudioBackground`.
- **Repo Audio & Timing Integration**: Support `ayah-recitation-*.json.zip` with direct ayah URLs and segment timestamps, `surah.json` + `segments.json`/`letter_segments.json`, and EveryAyah fallback for reciters without segment metadata.

## 6. Dynamic Tafsir Engine & Pointer References
- Download Tafsirs dynamically from direct links (Google Drive / GitHub / CDN) using `app_config.json`.
- Support both `.zip` and `.json` seamlessly with automatic extension fallback.
- **Shared Ayah Pointer Resolution**: When an Ayah entry in the JSON is a pointer reference string (e.g. `"2:9": "2:8"`), follow the pointer to the group object (`"2:8"`) to extract the full tafsir text.
- Clean HTML tags and parse footnotes `[[...]]` into `(...)`. Cache per surah with `.complete` marker file.
- Built-in "التفسير الميسر" must remain available 100% offline.

## 7. Screen Unlock Salawat (Audio Focus & Volume Ducking)
- MUST use Android **`SoundPool`** (preloaded audio in memory) to guarantee **0 ms delay** on screen unlock.
- MUST request transient audio focus (`AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK`) on `AudioManager` so it clearly plays over any active music/video by ducking the media.
- If phone speaker volume is very low or muted, dynamically raise volume for the Salawat and restore previous volume after playback.
- MUST trigger strictly on `Intent.ACTION_USER_PRESENT` with a 10-second debounce (`now - lastPlayTime < 10000L`).
- MUST strictly respect user-configured **Quiet Hours** and device **Silent/Vibrate Mode** (never play sound during sleep/quiet hours).

## 8. Google Drive Single-Prompt & Background Isha Auto-Sync
- **Interactive Sync**: Use `_isAuthenticating` lock to prevent multiple concurrent authentication popups on rapid button taps.
- **Background Auto-Sync After Isha**: `driveAutoSyncTask()` running in `AndroidAlarmManager` background isolate MUST call `GoogleSignIn.instance.attemptSilentSignIn()` to restore credentials and fetch fresh `authorizationHeaders` silently without UI.
- Never trigger false "account logged out" dialogs during app updates or background checks.

## 9. Salati (Prayer Focus) Stats, Colors & 10s Confirmation Timer
- **Stats Accuracy**: NEVER count future days of the week or unarrived prayers today as "missed" ("فائتة"). Only count prayers whose time has actually passed.
- **Theme Standard**: Remove all arbitrary green/teal colors; strictly use the app's gold theme palette (`AppColors.gold` / `#D0A871`).
- **10-Second Countdown Timer**: In both Native Kotlin overlay (`PrayerFocusOverlay.kt`) and Flutter modal (`prayer_alert_modal.dart`), the "صليتُ والله ✓" button MUST enforce a 10-second countdown timer `(10)...(1)` before becoming enabled/clickable to prevent accidental taps.
- **Home Screen Grid Title**: Title texts with ShaderMask (e.g. "صلاتي") must use `BlendMode.srcIn` with extra vertical bounds to ensure letters with descenders (e.g. dots of `ي`) are 100% golden.

## 10. Zero UI Freezing on Alarm/Notification Scheduling
- All prayer scheduling and alarm refreshes MUST run asynchronously in a background non-blocking microtask with an 800ms debounce.
- Provide a subtle non-blocking saving indicator on the prayer alarms screen so the user receives instant feedback without UI stutter.

## 11. Khatma & Friday Notification Integrity
- **Single Notification Guarantee**: Khatma daily wird alarms must have unique, deterministic IDs and cancel prior alarms before scheduling to prevent duplicate notifications firing at the same minute.
- **Friday Notifications**: Surat Al-Kahf and Friday Salawat reminders scheduled on Thursday night (after Isha) and Friday daytime (1 hour after Fajr).
- **Sound Clashes & Queuing**: Multiple simultaneous audible notifications are queued and spaced out sequentially via `NotificationQueueManager` (except for paired morning/evening azkar with ruqyah).
- **Wird Button State**: When opening a Wird for the first time, update state so the action button immediately reads "أكمل قراءة الورد".
- **Safe Image Export**: When capturing/exporting Wird pages, ensure route navigation does not pop the underlying view, and if the user is in Min view, switch to Full view for high-quality capture.

## 12. Share Card Layout & Natural Typography
- Card text format must use natural Arabic word spacing (`word.text` with standard single space) and centered/proportional container width (`height: 1.95`), preventing extreme gaps or stretched words.
- All repository card backgrounds and font assets must remain preserved.

## 13. Strict Silence & Disabled State Enforcement
- If any prayer, azkar, wird, or reminder is disabled or set to "none" in settings: it MUST NEVER send a notification or play audio.
- If sound is set to "صامت" / `silent_notif` / `silent`: post purely visual notifications.
- If device is in Silent mode (`RINGER_MODE_SILENT`) or Vibrate mode (`RINGER_MODE_VIBRATE`): never play sound.

## 14. Audio Focus Abandonment & Communication Mic Safety
- Whenever background audio completes (e.g. `ScreenUnlockReceiver` or Adhan/Azkar playback), the app MUST immediately call `audioManager.abandonAudioFocusRequest()` / `abandonAudioFocus()` and restore `audioManager.mode = AudioManager.MODE_NORMAL`.
- Never hold audio focus indefinitely or leave the audio manager in call modes, so that recording apps (WhatsApp voice notes, Discord calls, phone calls) never get blocked with "In call" errors.

## 15. Accountability Screen ("حاسب نفسك") & Salati Sync
- Today's prayers logged via "صلاتي" (`prayer_focus_log_$today`) MUST immediately reflect in the accountability screen ("حاسب نفسك") without getting wiped or resetting daily stats to 0%.
- Checking or unchecking prayers in "حاسب نفسك" must write back to both `temp_prayers` and `prayer_focus_log_$today`.

## 16. Mushaf Smooth Auto-Scroll
- Auto-scrolling MUST be powered by Flutter's `Ticker` (synchronized with 60/120Hz display VSYNC) and `itemExtent: screenHeight` on `ListView.builder` for constant O(1) layout time without frame drops. Never use high-frequency timers with synchronous `jumpTo`.

## 17. Prayer Focus Overlay Snooze Delay
- The "ذكرني بعد X دقائق" snooze button MUST enforce a 5-second countdown timer `(5)...(1)` before becoming clickable, while "صليتُ والله ✓" enforces a 10-second countdown timer.

## 18. Dynamic Tafsir Pointer Resolution
- Any cached or dynamic Tafsir ayah entry matching a pointer pattern (e.g. `"49:1"` or `^\d+:\d+$`) MUST be resolved dynamically to the root ayah text so users never see raw ayah index numbers.

## 19. Quiet Hours — Salawat & Takbeerat Only
- Quiet hours enforcement applies ONLY to: Salawat Al-Nabi notifications (AlarmIDs 8000–8999) and Takbeerat notifications (AlarmIDs 9000–9199). All other notifications (prayer adhans, azkar, wird, etc.) are NOT subject to quiet hours.
- Before applying quiet hours to Salawat: MUST check `flutter.quiet_hours_enabled == true`. If disabled, do NOT silence even if the time matches.
- Before applying quiet hours to Takbeerat: MUST check `flutter.takbeerat_quiet_hours_enabled == true`. If disabled, do NOT silence.

## 20. Repeat Notification Interval Minimum
- If `intervalMinutes × 60 ≤ estimated sound duration in seconds` → cancel the next repeat entirely (do not schedule it).
- If another notification fires at the same moment as a repeat cycle → fire the regular notification first, then schedule the next repeat from after that event.

## 21. Prayer Streak — Reset on Missed Prayer
- For completed past days (dayOffset > 0): if any prayer is not logged, the streak breaks immediately.
- For today (dayOffset == 0): compare each prayer against its actual scheduled time. If a prayer's time has PASSED and it is not logged → streak resets to 0. Prayers whose time has NOT yet arrived do not count for or against the streak.
- Streak restarts from 1 when the user logs the next prayer after a break.

## 22. Accountability Auto-Track
- Completing a Wird (Khatma) in `isolated_wird_screen.dart` MUST call `DailyTrackerService.markWirdDone(wirdTitle)` automatically — the user should not need to manually tick a checkbox.
- Completing Surah Al-Kahf on Friday MUST call `DailyTrackerService.markKahfDone()`. The Kahf checkbox in "حاسب نفسك" appears ONLY on Fridays.
- A Salawat Al-Nabi counter (numeric, not just a checkbox) MUST be present in the Quran section of "حاسب نفسك", saved per-day and persisted across app restarts.

## 23. Flip to Silence (قلب الهاتف للصمت)
- When the phone is flipped face-down (z < -8.0f), the audio must mute IMMEDIATELY.
- The phone remains silent AS LONG AS it is face-down. Even if a new Adhan or repeated notification starts while the phone is already face-down, it will immediately be muted (no face-up transition is required).
- It will only ring again when the phone is flipped back to a normal/face-up position.

## 24. Quran Reciters & Audio Theming Standards (ثيم القراء والمصحف الصوتي)
- **Dynamic Theme Color**: Quran Reciters screen (`QuranReadersScreen`), Audio player screen (`QuranAudioScreenBody`), Reciter cards (`ReciterWidget`), Surah cards (`SurahWidget`), Search bar (`RecitersSearchBar`), and Category headers MUST strictly follow the active theme color (`Theme.of(context).primaryColor`) like Tafseer, Fehres, and Bookmarks.
- **Adaptive Backgrounds**:
  - Light mode: Pure white (`Colors.white` / `#FFFFFF`).
  - Dark mode: Dark / Black (`Colors.black` / `const Color(0xFF000000)` / `const Color(0xFF1E1E1E)`).
- Never hardcode fixed static colors (e.g. fixed emerald green texture background) that ignore the user-selected theme.

