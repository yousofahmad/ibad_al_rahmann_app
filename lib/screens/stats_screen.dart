import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  // Stats for cards
  double _monthAverage = 0;
  double _weekAverage = 0;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('ar', null).then((_) {
      _loadHistory();
    });
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs
        .getKeys()
        .where((k) => k.startsWith('stats_'))
        .toList();

    List<Map<String, dynamic>> loadedData = [];
    double totalMonthScore = 0;
    int monthCount = 0;
    double totalWeekScore = 0;
    int weekCount = 0;

    DateTime now = DateTime.now();
    DateTime weekAgo = now.subtract(const Duration(days: 7));

    for (String key in allKeys) {
      String? jsonStr = prefs.getString(key);
      if (jsonStr != null) {
        Map<String, dynamic> data = json.decode(jsonStr);
        loadedData.add(data);

        // Parse date
        DateTime date = DateTime.parse(data['date']);
        double score = (data['total'] is double)
            ? data['total']
            : (data['total'] as int).toDouble();

        // Month stats (Current Month)
        if (date.month == now.month && date.year == now.year) {
          totalMonthScore += score;
          monthCount++;
        }

        // Week stats (Last 7 days)
        if (date.isAfter(weekAgo) &&
            date.isBefore(now.add(const Duration(days: 1)))) {
          totalWeekScore += score;
          weekCount++;
        }
      }
    }

    // Sort by date descending (newest first)
    loadedData.sort((a, b) {
      DateTime dateA = DateTime.parse(a['date']);
      DateTime dateB = DateTime.parse(b['date']);
      return dateB.compareTo(dateA);
    });

    if (mounted) {
      setState(() {
        _history = loadedData;
        _monthAverage = monthCount > 0 ? totalMonthScore / monthCount : 0;
        _weekAverage = weekCount > 0 ? totalWeekScore / weekCount : 0;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Theme Colors
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : const Color(0xFFF8F9FA);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    const goldColor = Color(0xFFD0A871);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          "الإحصائيات",
          style: TextStyle(
            fontFamily: AppConsts.expoArabic,
            fontWeight: FontWeight.bold,
            color: isDark ? goldColor : const Color(0xFF3E2723),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: isDark ? goldColor : Colors.black54,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: goldColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Notice Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: goldColor.withValues(alpha: 0.1),
                      border: Border.all(
                        color: goldColor.withValues(alpha: 0.3),
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: goldColor,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "حساب المتوسط لا يشمل الأيام التي لم تستخدم فيها التطبيق",
                            style: TextStyle(
                              fontFamily: AppConsts.expoArabic,
                              color: textColor.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.start,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Averages Cards
                  _buildProgressCard(
                    context,
                    "نسبة إنجاز هذا الشهر",
                    _monthAverage,
                    goldColor,
                    cardColor,
                    textColor,
                  ),
                  const SizedBox(height: 10),
                  _buildProgressCard(
                    context,
                    "نسبة إنجاز هذا الأسبوع",
                    _weekAverage,
                    goldColor,
                    cardColor,
                    textColor,
                  ),

                  const SizedBox(height: 25),

                  // Actions Row
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cardColor,
                            side: const BorderSide(color: goldColor),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text(
                            "البدء من جديد",
                            style: TextStyle(
                              fontFamily: AppConsts.expoArabic,
                              color: goldColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          decoration: BoxDecoration(
                            color: goldColor,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: goldColor.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.history,
                                color: Colors.white,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                "آخر 31 يوم",
                                style: TextStyle(
                                  fontFamily: AppConsts.expoArabic,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 25),

                  // Daily History List
                  if (_history.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(50.0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.analytics_outlined,
                            size: 50,
                            color: textColor.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "لا توجد سجلات سابقة",
                            style: TextStyle(
                              fontFamily: AppConsts.expoArabic,
                              color: textColor.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._history.map(
                      (data) => _buildDayCard(
                        data,
                        cardColor,
                        textColor,
                        goldColor,
                        isDark,
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildProgressCard(
    BuildContext context,
    String title,
    double percent,
    Color goldColor,
    Color cardColor,
    Color textColor,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: goldColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: AppConsts.expoArabic,
              color: textColor.withValues(alpha: 0.8),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "${percent.toInt()}%",
            style: TextStyle(
              fontFamily: AppConsts.expoArabic,
              color: goldColor,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCard(
    Map<String, dynamic> data,
    Color cardColor,
    Color textColor,
    Color goldColor,
    bool isDark,
  ) {
    DateTime date = DateTime.parse(data['date']);
    String dayName = DateFormat('EEEE', 'ar').format(date);
    String dateStr = "${date.day}-${date.month}-${date.year}";

    return Container(
      margin: const EdgeInsets.only(bottom: 25),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: goldColor.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Day number badge
          Positioned(
            top: -40,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: goldColor,
                  border: Border.all(color: cardColor, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: goldColor.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    "${date.day}",
                    style: const TextStyle(
                      fontFamily: AppConsts.expoArabic,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),

          Column(
            children: [
              const SizedBox(height: 15),

              // Date & Day Name
              Text(
                dayName,
                style: TextStyle(
                  fontFamily: AppConsts.expoArabic,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: goldColor,
                ),
              ),
              Text(
                dateStr,
                style: TextStyle(
                  fontFamily: AppConsts.expoArabic,
                  fontSize: 14,
                  color: textColor.withValues(alpha: 0.5),
                ),
              ),
              const Divider(height: 30),

              // Stats Rows
              _buildStatRow("الصلاة", data['prayer'] ?? 0, textColor),
              _buildStatRow("القرآن الكريم", data['quran'] ?? 0, textColor),
              _buildStatRow("الأذكار", data['azkar'] ?? 0, textColor),
              _buildStatRow("الطاعات", data['deeds'] ?? 0, textColor),

              const Divider(height: 30),

              // Total Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "إنجاز اليوم",
                    style: TextStyle(
                      fontFamily: AppConsts.expoArabic,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: goldColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "${(data['total'] ?? 0).toInt()}%",
                      style: TextStyle(
                        fontFamily: AppConsts.expoArabic,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: goldColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, dynamic val, Color textColor) {
    int percent = (val is double) ? val.toInt() : val;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: AppConsts.expoArabic,
              fontSize: 14,
              color: textColor,
            ),
          ),
          Text(
            "$percent%",
            style: TextStyle(
              fontFamily: AppConsts.expoArabic,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: textColor.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
