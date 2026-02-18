import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ibad_al_rahmann/services/prayer_service.dart';
import 'azkar_page.dart';
import 'ruqyah_screen.dart';
import 'azkar_statistics_screen.dart';

class MuslimAzkarScreen extends StatelessWidget {
  const MuslimAzkarScreen({super.key});

  Widget _buildAzkarButton(
    BuildContext context,
    String title,
    IconData icon,
    Widget targetScreen,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).cardColor, // Theme Card Color
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFD0A871), width: 1),
          ),
          elevation: 0,
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => targetScreen),
          );
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: const Color(0xFFD0A871), size: 28),
            Text(
              title,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).textTheme.bodyLarge?.color, // Theme Text
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Theme BG
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with Stats & Alerts
              Row(
                children: [
                  Expanded(
                    child: _buildHeaderButton(
                      context,
                      "الإحصائيات",
                      FontAwesomeIcons.chartBar,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AzkarStatisticsScreen(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildHeaderButton(
                      context,
                      "التنبيهات",
                      FontAwesomeIcons.solidBell,
                      () => _showNotificationSettings(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Vertical List
              Expanded(
                child: ListView(
                  children: [
                    _buildAzkarButton(
                      context,
                      "أذكار الصباح",
                      Icons.wb_sunny,
                      const AzkarPage(
                        title: "أذكار الصباح",
                        jsonFile: "morning.json",
                        image: "assets/images/morning.jpg",
                      ),
                    ),
                    _buildAzkarButton(
                      context,
                      "أذكار المساء",
                      Icons.nights_stay,
                      const AzkarPage(
                        title: "أذكار المساء",
                        jsonFile: "evening.json",
                        image: "assets/images/night.jpg",
                      ),
                    ),
                    _buildAzkarButton(
                      context,
                      "أذكار الصلاة",
                      Icons.mosque,
                      const AzkarPage(
                        title: "أذكار الصلاة",
                        jsonFile: "prayer.json",
                        image: "assets/images/mosque.jpg",
                      ),
                    ),
                    _buildAzkarButton(
                      context,
                      "الرقية الشرعية",
                      Icons.shield,
                      const RuqyahScreen(),
                    ),
                    // _buildAzkarButton(
                    //   context,
                    //   "أذكار المسجد",
                    //   Icons.location_city,
                    //   const AzkarPage(title: "أذكار المسجد", jsonFile: "mosque.json", image: "assets/images/mosque.jpg"),
                    // ),
                    // _buildAzkarButton(
                    //   context,
                    //   "أذكار الوضوء",
                    //   Icons.water_drop,
                    //   const AzkarPage(title: "أذكار الوضوء", jsonFile: "wudu.json", image: "assets/images/mosque.jpg"),
                    // ),
                    // _buildAzkarButton(
                    //   context,
                    //   "أذكار النوم",
                    //   Icons.bed,
                    //   const AzkarPage(title: "أذكار النوم", jsonFile: "sleep.json", image: "assets/images/night.jpg"),
                    // ),
                    // _buildAzkarButton(
                    //   context,
                    //   "أذكار الاستيقاظ",
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderButton(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    const borderColor = Color(0xFFD0A871);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.grey.withAlpha(20),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: borderColor, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNotificationSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const _AzkarAlertsSheet(),
    );
  }
}

class _AzkarAlertsSheet extends StatefulWidget {
  const _AzkarAlertsSheet();

  @override
  State<_AzkarAlertsSheet> createState() => _AzkarAlertsSheetState();
}

class _AzkarAlertsSheetState extends State<_AzkarAlertsSheet> {
  // State
  bool _morning = true;
  bool _evening = true;

  TimeOfDay _morningTime = const TimeOfDay(hour: 6, minute: 0);
  TimeOfDay _eveningTime = const TimeOfDay(hour: 17, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _morning = prefs.getBool('notif_azkar_morning') ?? true;
      _evening = prefs.getBool('notif_azkar_evening') ?? true;

      final m = (prefs.getString('time_azkar_morning') ?? "06:00").split(":");
      _morningTime = TimeOfDay(hour: int.parse(m[0]), minute: int.parse(m[1]));

      final e = (prefs.getString('time_azkar_evening') ?? "17:00").split(":");
      _eveningTime = TimeOfDay(hour: int.parse(e[0]), minute: int.parse(e[1]));
    });
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_azkar_morning', _morning);
    await prefs.setBool('notif_azkar_evening', _evening);

    await prefs.setString(
      'time_azkar_morning',
      "${_morningTime.hour}:${_morningTime.minute}",
    );
    await prefs.setString(
      'time_azkar_evening',
      "${_eveningTime.hour}:${_eveningTime.minute}",
    );

    // Reschedule
    // In a real app we'd call a dedicated reschedule method.
    // Assuming NotificationService.scheduleDefaults() or similar exists and checks these.
    // Or we manually schedule here for "Instant" feedback if service allows.
    // For now we assume service reads these prefs on next run or we re-trigger.
    // But better to trigger:
    PrayerService().scheduleNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "تنبيهات الأذكار",
            style: TextStyle(
              color: Color(0xFFD0A871),
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 20),
          _buildToggleItem(
            "أذكار الصباح",
            _morning,
            (v) => setState(() => _morning = v),
            _morningTime,
            (t) => setState(() => _morningTime = t),
          ),
          _buildToggleItem(
            "أذكار المساء",
            _evening,
            (v) => setState(() => _evening = v),
            _eveningTime,
            (t) => setState(() => _eveningTime = t),
          ),

          // Ruqyah toggle removed per user request
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD0A871),
                foregroundColor: Colors.black,
              ),
              onPressed: () async {
                await _savePrefs();
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text(
                "حفظ",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleItem(
    String title,
    bool val,
    ValueChanged<bool> onToggle,
    TimeOfDay time,
    ValueChanged<TimeOfDay> onTime,
  ) {
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

    return Row(
      children: [
        Checkbox(
          value: val,
          activeColor: const Color(0xFFD0A871),
          checkColor: Colors.black,
          onChanged: (v) => onToggle(v!),
        ),
        Text(
          title,
          style: TextStyle(color: textColor, fontFamily: 'Cairo'),
        ),
        const Spacer(),
        if (val)
          TextButton(
            onPressed: () async {
              final t = await showTimePicker(
                context: context,
                initialTime: time,
              );
              if (t != null) onTime(t);
            },
            child: Text(
              "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}",
              style: const TextStyle(color: Color(0xFFD0A871)),
            ),
          ),
      ],
    );
  }
}
