import 'package:flutter/material.dart';
// Assuming screenutil is used project-wide
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
// For PrayerTimes calculation context if needed
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:ibad_al_rahmann/services/notification_service.dart';
import 'package:ibad_al_rahmann/services/prayer_service.dart';

class QuranWirdScreen extends StatefulWidget {
  const QuranWirdScreen({super.key});

  @override
  State<QuranWirdScreen> createState() => _QuranWirdScreenState();
}

class _QuranWirdScreenState extends State<QuranWirdScreen> {
  final TextEditingController _daysController = TextEditingController();
  int _pagesPerDay = 0;

  // Reminder Settings
  String _reminderType = 'none'; // none, daily, prayer
  TimeOfDay _dailyTime = const TimeOfDay(hour: 20, minute: 0);
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      int days = prefs.getInt('wird_days') ?? 30;
      _daysController.text = days.toString();
      _calculatePages();

      _reminderType = prefs.getString('wird_reminder_type') ?? 'none';

      final t = (prefs.getString('wird_daily_time') ?? "20:00").split(":");
      _dailyTime = TimeOfDay(hour: int.parse(t[0]), minute: int.parse(t[1]));
    });
  }

  // Madinah mushaf juz start pages (0-indexed: juz 1 starts at page 1)
  static const List<int> _juzStartPages = [
    1, 22, 42, 62, 82, 102, 121, 142, 162, 182, // Juz 1-10
    201, 222, 242, 262, 282, 302, 322, 342, 362, 382, // Juz 11-20
    402, 422, 442, 462, 482, 502, 522, 542, 562, 582, // Juz 21-30
  ];

  // Returns list of (startPage, endPage) for each day based on juz distribution
  static List<List<int>> getWirdDayRanges(int days) {
    if (days <= 0) days = 1;
    if (days > 604) days = 604;

    final List<List<int>> ranges = [];

    if (days <= 30) {
      // Distribute 30 ajza' across N days
      // Each day gets (30/days) ajza'
      double ajzaaPerDay = 30 / days;
      double juzAccum = 0;

      for (int d = 0; d < days; d++) {
        double fromJuz = juzAccum;
        juzAccum += ajzaaPerDay;
        double toJuz = juzAccum;

        int fromJuzIdx = fromJuz.floor(); // 0-indexed
        int toJuzIdx = (toJuz - 0.001).floor(); // inclusive end juz

        if (fromJuzIdx >= 30) fromJuzIdx = 29;
        if (toJuzIdx >= 30) toJuzIdx = 29;

        int startPage = _juzStartPages[fromJuzIdx];
        int endPage = (toJuzIdx + 1 < 30)
            ? _juzStartPages[toJuzIdx + 1] - 1
            : 604;

        ranges.add([startPage, endPage]);
      }
    } else {
      // More than 30 days: distribute 604 pages simply
      int pagesPerDay = (604 / days).floor();
      int remainder = 604 - (pagesPerDay * days);
      int currentPage = 1;

      for (int d = 0; d < days; d++) {
        int todayPages = pagesPerDay + (d < remainder ? 1 : 0);
        int endPage = currentPage + todayPages - 1;
        if (endPage > 604) endPage = 604;
        ranges.add([currentPage, endPage]);
        currentPage = endPage + 1;
        if (currentPage > 604) break;
      }
    }

    return ranges;
  }

  void _calculatePages() {
    int days = int.tryParse(_daysController.text) ?? 30;
    if (days <= 0) days = 1;
    final ranges = getWirdDayRanges(days);
    // Show average pages per day
    int totalPages = 0;
    for (var r in ranges) {
      totalPages += (r[1] - r[0] + 1);
    }
    setState(() {
      _pagesPerDay = (totalPages / ranges.length).round();
    });
  }

  Future<void> _saveAndSchedule() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();

    int days = int.tryParse(_daysController.text) ?? 30;
    if (days <= 0) days = 1;

    // Reset Start Date
    DateTime now = DateTime.now();
    DateTime startDate = now;

    if (_reminderType == 'daily') {
      startDate = DateTime(
        now.year,
        now.month,
        now.day,
        _dailyTime.hour,
        _dailyTime.minute,
      );
      if (startDate.isBefore(now)) {
        startDate = startDate.add(const Duration(days: 1));
      }
    } else {
      // Prayer type: Start date is effectively today (passed prayers skipped)
      startDate = now;
    }

    await prefs.setString('wird_start_date', startDate.toIso8601String());
    await prefs.setInt('wird_days', days);
    await prefs.setString('wird_reminder_type', _reminderType);
    await prefs.setString(
      'wird_daily_time',
      "${_dailyTime.hour}:${_dailyTime.minute}",
    );

    // Cancel old Wird & reschedule
    await NotificationService.cancelAll(includeWird: true);
    await NotificationService.rescheduleWird();
    // Re-schedule prayer/azkar notifications that cancelAll removed
    PrayerService().scheduleNotifications();

    setState(() => _isLoading = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("تم حفظ الجدول وتفعيل التنبيهات")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : const Color(0xFFF5F5F5);
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          "ختمة القرآن",
          style: TextStyle(
            color: Color(0xFFD0A871),
            fontFamily: AppConsts.expoArabic,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Color(0xFFD0A871)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Goal Section
            _buildCard(
              context: context,
              title: "هدفك",
              icon: FontAwesomeIcons.bullseye,
              child: Column(
                children: [
                  Text(
                    "أريد ختم القرآن في:",
                    style: TextStyle(color: textColor, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 100,
                        child: TextField(
                          controller: _daysController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFD0A871),
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: const InputDecoration(
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFFD0A871)),
                            ),
                          ),
                          onChanged: (_) => _calculatePages(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        "يوم",
                        style: TextStyle(color: textColor, fontSize: 16),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 2. Result Section
            _buildCard(
              context: context,
              title: "الورد اليومي",
              icon: FontAwesomeIcons.bookOpen,
              child: Column(
                children: [
                  Text(
                    "يتطلب قراءة",
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "$_pagesPerDay",
                    style: const TextStyle(
                      color: Color(0xFFD0A871),
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "صفحة يومياً",
                    style: TextStyle(color: textColor, fontSize: 18),
                  ),
                  if (_reminderType == 'prayer')
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        "(أو حوالي ${(_pagesPerDay / 5).ceil()} صفحات بعد كل صلاة)",
                        style: TextStyle(
                          color: isDark ? Colors.grey[500] : Colors.grey[700],
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 3. Reminders Section
            _buildCard(
              context: context,
              title: "التذكير",
              icon: FontAwesomeIcons.bell,
              child: RadioGroup<String>(
                groupValue: _reminderType,
                onChanged: (v) {
                  if (v != null) setState(() => _reminderType = v);
                },
                child: Column(
                  children: [
                    RadioListTile<String>(
                      title: Text(
                        "بدون تذكير",
                        style: TextStyle(color: textColor),
                      ),
                      value: 'none',
                      activeColor: const Color(0xFFD0A871),
                    ),
                    RadioListTile<String>(
                      title: Text(
                        "مرة يومياً",
                        style: TextStyle(color: textColor),
                      ),
                      value: 'daily',
                      activeColor: const Color(0xFFD0A871),
                      secondary: _reminderType == 'daily'
                          ? TextButton(
                              onPressed: () async {
                                final t = await showTimePicker(
                                  context: context,
                                  initialTime: _dailyTime,
                                );
                                if (t != null) setState(() => _dailyTime = t);
                              },
                              child: Text(
                                "${_dailyTime.hour}:${_dailyTime.minute.toString().padLeft(2, '0')}",
                                style: const TextStyle(
                                  color: Color(0xFFD0A871),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : null,
                    ),
                    RadioListTile<String>(
                      title: Text(
                        "توزيع بعد الصلوات",
                        style: TextStyle(color: textColor),
                      ),
                      subtitle: Text(
                        "تذكير بعد 15 دقيقة من كل صلاة",
                        style: TextStyle(
                          color: isDark ? Colors.grey : Colors.grey[700],
                          fontSize: 10,
                        ),
                      ),
                      value: 'prayer',
                      activeColor: const Color(0xFFD0A871),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD0A871),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isLoading ? null : _saveAndSchedule,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.black)
                  : const Text(
                      "حفظ وتفعيل",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
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
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: const Color(0xFFD0A871), size: 20),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFFD0A871),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 30),
          child,
        ],
      ),
    );
  }
}
