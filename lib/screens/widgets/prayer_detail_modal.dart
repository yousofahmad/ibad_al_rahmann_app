import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ibad_al_rahmann/services/prayer_service.dart';
import 'package:ibad_al_rahmann/screens/muezzin_selection_screen.dart';
import 'package:ibad_al_rahmann/core/constants/prayer_text_data.dart';
import 'dart:async';

class PrayerDetailModal extends StatefulWidget {
  final ExtendedPrayer prayer;
  const PrayerDetailModal({super.key, required this.prayer});

  @override
  State<PrayerDetailModal> createState() => _PrayerDetailModalState();
}

class _PrayerDetailModalState extends State<PrayerDetailModal> {
  int _adhanOffset = 0;
  bool _isNotifEnabled = true;
  bool _isIqamaEnabled = false;
  int _iqamaDelay = 15;

  String _selectedSoundName = "الافتراضي";

  @override
  void initState() {
    super.initState();
    _loadOffset();
    _loadNotifStatus();
    _loadSound();
    _loadIqamaSettings();
  }

  Future<void> _loadIqamaSettings() async {
    String key =
        widget.prayer.id[0].toUpperCase() + widget.prayer.id.substring(1);
    // Default logic matching NotificationService
    int def = (key == 'Maghrib' ? 10 : (key == 'Fajr' ? 20 : 15));

    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isIqamaEnabled = prefs.getBool('iqama_enabled_$key') ?? false;
      _iqamaDelay = prefs.getInt('iqama_minutes_$key') ?? def;
    });
  }

  /// Returns the correct SharedPreferences key for this prayer's notification toggle
  String _getNotifKey() {
    final id = widget.prayer.id.toLowerCase();
    // Fard prayers use notif_prayer_<id>
    if (widget.prayer.prayer != null) {
      return 'notif_prayer_$id';
    }
    // Non-fard prayers use their specific keys
    switch (id) {
      case 'duha':
        return 'notif_duha';
      case 'sunrise':
        return 'notif_sunrise';
      case 'qiyam':
      case 'witr':
        return 'notif_qiyam';
      case 'first_third':
        return 'notif_first_third';
      case 'last_third':
        return 'notif_qiyam';
      case 'midnight':
        return 'notif_midnight';
      default:
        return 'notif_prayer_$id';
    }
  }

  /// Returns the default enabled state for this prayer's notification
  bool _getNotifDefault() {
    final id = widget.prayer.id.toLowerCase();
    // Fard prayers default to ON, non-fard default to OFF
    if (widget.prayer.prayer != null) return true;
    if (id == 'sunrise') return true;
    return false;
  }

  Future<void> _loadNotifStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isNotifEnabled = prefs.getBool(_getNotifKey()) ?? _getNotifDefault();
    });
  }

  Future<void> _loadSound() async {
    final prefs = await SharedPreferences.getInstance();
    String key = 'adhan_sound_${widget.prayer.id.toLowerCase()}';
    String? path = prefs.getString(key);

    if (path == null || path == 'default') {
      if (mounted) setState(() => _selectedSoundName = "الافتراضي");
    } else {
      // Simple name resolution or placeholder
      // To be perfect we'd load repository, but for speed:
      // Try to get name if possible or just show "مخصص"
      // Let's try to verify if it's one of the known muezzins
      // Instantiate repo only if needed
      if (mounted) {
        setState(() => _selectedSoundName = "مخصص (${path.split('/').last})");
      }
    }
  }

  void _loadOffset() {
    // Only standard prayers have offsets in PrayerService for now
    if (widget.prayer.prayer != null) {
      // Need a way to get adjustment for specific prayer ID
      // PrayerService key logic: keys are Capitalized 'Fajr', 'Dhuhr' etc.
      // Widget.prayer.id is 'fajr'. Capitalize it.
      String key =
          widget.prayer.id[0].toUpperCase() + widget.prayer.id.substring(1);
      if (key == 'First_third' ||
          key == 'Last_third' ||
          key == 'Witr' ||
          key == 'Duha' ||
          key == 'Midnight') {
        return;
      }

      setState(() {
        _adhanOffset = PrayerService().adjustments[key] ?? 0;
      });
    }
  }

  Future<void> _updateOffset(int delta) async {
    // Logic similar to _loadOffset
    String key =
        widget.prayer.id[0].toUpperCase() + widget.prayer.id.substring(1);
    int newValue = _adhanOffset + delta;

    await PrayerService().saveAdjustment(key, newValue);
    setState(() {
      _adhanOffset = newValue;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final containerColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white10 : Colors.black12;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.prayer.name,
                  style: const TextStyle(
                    fontFamily: AppConsts.expoArabic,
                    color: Color(0xFFD0A871),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  PrayerService().formatTime(widget.prayer.time),
                  style: TextStyle(
                    fontFamily: AppConsts.expoArabic,
                    color: textColor,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Religious Text Card
            if (prayerDescriptions.containsKey(widget.prayer.id))
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: containerColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFD0A871).withOpacity(0.2),
                  ),
                  boxShadow: isDark
                      ? null
                      : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Text(
                  prayerDescriptions[widget.prayer.id]!,
                  style: TextStyle(
                    fontFamily: AppConsts.expoArabic,
                    color: textColor,
                    fontSize: 14,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.justify,
                  // textDirection: TextDirection.rtl,
                ),
              ),

            // Smart Timer Section
            _buildSmartTimer(isDark),
            const SizedBox(height: 16),

            if (widget.prayer.prayer != null ||
                widget.prayer.id == 'duha' ||
                widget.prayer.id == 'witr' ||
                widget.prayer.id == 'sunrise' ||
                widget.prayer.id == 'first_third' ||
                widget.prayer.id == 'midnight' ||
                widget.prayer.id == 'last_third') ...[
              // Manual Adjustment (Only for Fard)
              if (widget.prayer.prayer != null)
                _buildAdjustmentRow(
                  "تعديل الموعد (دقائق)",
                  _adhanOffset,
                  _updateOffset,
                  isDark,
                ),

              const SizedBox(height: 16),

              // Notification Toggles & Sound
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: containerColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                  boxShadow: isDark
                      ? null
                      : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.notifications_active,
                        color: Color(0xFFD0A871),
                      ),
                      title: Text(
                        "تفعيل التنبيه",
                        style: TextStyle(
                          fontFamily: AppConsts.expoArabic,
                          color: textColor,
                          fontSize: 14,
                        ),
                      ),
                      trailing: Switch(
                        value: _isNotifEnabled,
                        onChanged: (v) async {
                          setState(() => _isNotifEnabled = v);
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool(_getNotifKey(), v);
                          PrayerService().scheduleNotifications();
                        },
                        activeThumbColor: const Color(0xFFD0A871),
                      ),
                    ),
                    Divider(color: borderColor),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.music_note,
                        color: Color(0xFFD0A871),
                      ),
                      title: Text(
                        "نغمة التنبيه",
                        style: TextStyle(
                          fontFamily: AppConsts.expoArabic,
                          color: textColor,
                          fontSize: 14,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            constraints: const BoxConstraints(maxWidth: 100),
                            child: Text(
                              _selectedSoundName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: AppConsts.expoArabic,
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.grey,
                            size: 14,
                          ),
                        ],
                      ),
                      onTap: () async {
                        // Navigate to sound selection
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MuezzinSelectionScreen(
                              prefsKey:
                                  'adhan_sound_${widget.prayer.id.toLowerCase()}',
                              title: 'أذان ${widget.prayer.name}',
                            ),
                          ),
                        );
                        _loadSound(); // Refresh after return
                        PrayerService().scheduleNotifications();
                      },
                    ),
                    if (widget.prayer.prayer != null) ...[
                      Divider(color: borderColor),
                      // Iqama Settings
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.timer_outlined,
                          color: Color(0xFFD0A871),
                        ),
                        title: Text(
                          "إقامة الصلاة",
                          style: TextStyle(
                            fontFamily: AppConsts.expoArabic,
                            color: textColor,
                            fontSize: 14,
                          ),
                        ),
                        trailing: Switch(
                          value: _isIqamaEnabled,
                          onChanged: (v) async {
                            setState(() => _isIqamaEnabled = v);
                            String key =
                                widget.prayer.id[0].toUpperCase() +
                                widget.prayer.id.substring(1);
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('iqama_enabled_$key', v);
                            PrayerService().scheduleNotifications();
                          },
                          activeThumbColor: const Color(0xFFD0A871),
                        ),
                      ),
                      if (_isIqamaEnabled) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "وقت الإقامة (دقائق)",
                                style: TextStyle(
                                  fontFamily: AppConsts.cairo,
                                  color: textColor.withOpacity(0.7),
                                  fontSize: 13,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF303030)
                                      : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    InkWell(
                                      onTap: () async {
                                        if (_iqamaDelay > 1) {
                                          setState(() => _iqamaDelay--);
                                          String key =
                                              widget.prayer.id[0]
                                                  .toUpperCase() +
                                              widget.prayer.id.substring(1);
                                          final prefs =
                                              await SharedPreferences.getInstance();
                                          await prefs.setInt(
                                            'iqama_minutes_$key',
                                            _iqamaDelay,
                                          );
                                          PrayerService()
                                              .scheduleNotifications();
                                        }
                                      },
                                      child: const Icon(Icons.remove, size: 18),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      child: Text(
                                        "$_iqamaDelay",
                                        style: const TextStyle(
                                          fontFamily: AppConsts.expoArabic,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () async {
                                        if (_iqamaDelay < 60) {
                                          setState(() => _iqamaDelay++);
                                          String key =
                                              widget.prayer.id[0]
                                                  .toUpperCase() +
                                              widget.prayer.id.substring(1);
                                          final prefs =
                                              await SharedPreferences.getInstance();
                                          await prefs.setInt(
                                            'iqama_minutes_$key',
                                            _iqamaDelay,
                                          );
                                          PrayerService()
                                              .scheduleNotifications();
                                        }
                                      },
                                      child: const Icon(Icons.add, size: 18),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD0A871),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                "إغلاق",
                style: TextStyle(
                  fontFamily: AppConsts.cairo,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmartTimer(bool isDark) {
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, snapshot) {
        final now = DateTime.now();
        final prayerTime = widget.prayer.time;
        final isFuture = prayerTime.isAfter(now);
        final diff = isFuture
            ? prayerTime.difference(now)
            : now.difference(prayerTime);

        String twoDigits(int n) => n.toString().padLeft(2, "0");
        final timerStr =
            "${twoDigits(diff.inHours)}:${twoDigits(diff.inMinutes.remainder(60))}:${twoDigits(diff.inSeconds.remainder(60))}";

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF121212) : Colors.grey[100],
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: isFuture
                  ? const Color(0xFFD0A871)
                  : (isDark ? Colors.white10 : Colors.black12),
            ),
          ),
          child: Column(
            children: [
              if (isFuture) ...[
                Text(
                  widget.prayer.prayer != null
                      ? "متبقي على الأذان"
                      : "متبقي على الموعد",
                  style: const TextStyle(
                    fontFamily: AppConsts.expoArabic,
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ] else ...[
                Text(
                  widget.prayer.prayer != null
                      ? "مر على الأذان"
                      : "مر على الموعد",
                  style: const TextStyle(
                    fontFamily: AppConsts.expoArabic,
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ],
              const SizedBox(height: 5),
              Text(
                timerStr,
                style: TextStyle(
                  fontFamily: 'Courier', // Monospace
                  color: isFuture
                      ? const Color(0xFFD0A871)
                      : (isDark ? Colors.white : Colors.black),
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAdjustmentRow(
    String label,
    int value,
    Function(int) onChanged,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: AppConsts.cairo,
            color: Colors.grey,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(
                  Icons.remove,
                  color: isDark ? Colors.white : Colors.black,
                ),
                onPressed: () => onChanged(-1),
              ),
              Row(
                children: [
                  Text(
                    "$value",
                    style: const TextStyle(
                      fontFamily: AppConsts.expoArabic,
                      color: Color(0xFFD0A871),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    "دقيقة",
                    style: TextStyle(
                      fontFamily: AppConsts.expoArabic,
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(
                  Icons.add,
                  color: isDark ? Colors.white : Colors.black,
                ),
                onPressed: () => onChanged(1),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
