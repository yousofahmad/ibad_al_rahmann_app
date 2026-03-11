import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import '../bloc/khatma_cubit.dart';
import '../utils/wird_calculator.dart';

class QuranWirdScreen extends StatefulWidget {
  const QuranWirdScreen({super.key});

  @override
  State<QuranWirdScreen> createState() => _QuranWirdScreenState();
}

class _QuranWirdScreenState extends State<QuranWirdScreen> {
  final TextEditingController _daysController = TextEditingController();
  int _pagesPerDay = 0;

  // Multiple Khatma Support
  String _currentKhatmaId = 'khatma_1';
  final Map<String, String> _khatmas = {
    'khatma_1': 'الختمة الأولى',
    'khatma_2': 'الختمة الثانية',
    'ramadan': 'ختمة رمضان',
  };

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
      int days = prefs.getInt('${_currentKhatmaId}_wird_days') ?? 30;
      _daysController.text = days.toString();
      _calculatePages();

      _reminderType =
          prefs.getString('${_currentKhatmaId}_wird_reminder_type') ?? 'none';

      final t =
          (prefs.getString('${_currentKhatmaId}_wird_daily_time') ?? "20:00")
              .split(":");
      _dailyTime = TimeOfDay(hour: int.parse(t[0]), minute: int.parse(t[1]));
    });
  }

  void _calculatePages() {
    int days = int.tryParse(_daysController.text) ?? 30;
    if (days <= 0) days = 1;

    // Use WirdCalculator for consistent calculation
    setState(() {
      _pagesPerDay =
          WirdCalculator.getPagesPerDay(
            amount: 1,
            unit: WirdUnit.juz,
            isPerPrayer: false,
          ) *
          30 ~/
          days;
    });
  }

  Future<void> _saveAndSchedule() async {
    setState(() => _isLoading = true);

    int days = int.tryParse(_daysController.text) ?? 30;
    if (days <= 0) days = 1;

    try {
      await context.read<KhatmaCubit>().startNewKhatma(
        id: _currentKhatmaId,
        name: _khatmas[_currentKhatmaId]!,
        totalDays: days,
        notificationType: _reminderType,
        unit: WirdUnit
            .page, // Default to page-based distribution for this simplified UI
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('${_currentKhatmaId}_wird_days', days);
      await prefs.setString(
        '${_currentKhatmaId}_wird_reminder_type',
        _reminderType,
      );
      await prefs.setString(
        '${_currentKhatmaId}_wird_daily_time',
        "${_dailyTime.hour}:${_dailyTime.minute}",
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "تم حفظ الجدول وتفعيل التنبيهات لـ ${_khatmas[_currentKhatmaId]}",
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("حدث خطأ أثناء الحفظ: $e")));
      }
    } finally {
      setState(() => _isLoading = false);
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
            // 0. Khatma Selector
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _khatmas.entries.map((e) {
                  bool isSelected = _currentKhatmaId == e.key;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: ChoiceChip(
                      label: Text(e.value),
                      selected: isSelected,
                      onSelected: (val) async {
                        if (val) {
                          final khatmaCubit = context.read<KhatmaCubit>();
                          setState(() {
                            _currentKhatmaId = e.key;
                          });
                          await _loadData();
                          if (mounted) {
                            khatmaCubit.loadKhatma(
                              specificId: e.key,
                            );
                          }
                        }
                      },
                      selectedColor: const Color(0xFFD0A871),
                      backgroundColor: isDark ? Colors.white10 : Colors.white,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Colors.black
                            : (isDark ? Colors.white70 : Colors.black54),
                        fontFamily: AppConsts.cairo,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

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
                  color: Colors.black.withValues(alpha: 0.05),
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
