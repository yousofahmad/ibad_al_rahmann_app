import 'dart:async';
import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:intl/intl.dart';
import 'package:hijri/hijri_calendar.dart';
import '../services/prayer_service.dart';
import 'widgets/prayer_detail_modal.dart';
import 'widgets/prayer_ring_widget.dart'; // We will create this

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  List<ExtendedPrayer> _prayers = [];
  List<ExtendedPrayer> _tomorrowPrayers = []; // Add tomorrow list
  ExtendedPrayer? _nextPrayer;
  Timer? _timer;
  Duration _timeToNext = Duration.zero;

  static const Color _goldColor = Color(0xFFD0A871);

  @override
  void initState() {
    super.initState();
    _loadData();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) => _updateCountdown(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final todayPrayers = await PrayerService().getExtendedPrayers();
    final tomorrowPrayers = await PrayerService().getExtendedPrayers(
      date: DateTime.now().add(const Duration(days: 1)),
    );

    if (mounted) {
      setState(() {
        _prayers = todayPrayers;
        _tomorrowPrayers = tomorrowPrayers;
        _updateNextPrayer();
      });
    }
  }

  void _updateNextPrayer() {
    if (_prayers.isEmpty) return;
    final now = DateTime.now();

    // Find next FARD prayer (skip Sunrise)
    ExtendedPrayer? next;
    for (var p in _prayers) {
      // Skip Sunrise (and non-Fard if any others added to this list)
      if (p.prayer == Prayer.sunrise) continue;

      if (p.time.isAfter(now)) {
        next = p;
        break;
      }
    }

    // If no next Fard prayer today, check tomorrow's Fard prayers
    if (next == null && _tomorrowPrayers.isNotEmpty) {
      for (var p in _tomorrowPrayers) {
        if (p.prayer == Prayer.sunrise) continue;
        next = p;
        break; // First Fard of tomorrow
      }
    }

    _nextPrayer = next;
    _updateCountdown();
  }

  void _updateCountdown() {
    if (_nextPrayer == null) return;
    final now = DateTime.now();

    // Handle wrap around for next day Fajr if needed
    DateTime target = _nextPrayer!.time;
    if (target.isBefore(now)) {
      // If target passed, reload logic or assume it's tomorrow
      // Simple fix: reload prayers if day changed or all passed
      _loadData();
      return;
    }

    setState(() {
      _timeToNext = target.difference(now);
    });
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(d.inHours)}:${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
  }

  @override
  Widget build(BuildContext context) {
    final hijriOffset = PrayerService().hijriOffset;
    final adjustedDate = DateTime.now().add(Duration(days: hijriOffset));
    final todayHijri = HijriCalendar.fromDate(adjustedDate);
    final hijriStr =
        "${todayHijri.hDay} ${todayHijri.longMonthName} ${todayHijri.hYear}";
    final gregStr = DateFormat(
      'd MMMM yyyy',
      'ar',
    ).format(DateTime.now()); // Arabic Locale

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "مواقيت الصلاة",
          style: TextStyle(
            fontFamily: AppConsts.expoArabic,
            color: _goldColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: _goldColor),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _prayers.isEmpty
          ? const Center(child: CircularProgressIndicator(color: _goldColor))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // Top Section: Ring & Countdown
                  SizedBox(
                    height: 240, // Slightly increased height
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const PrayerRingWidget(
                          percent: 0.75,
                          color: _goldColor,
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "المتبقي لـ ${_nextPrayer?.name ?? ''}",
                              style: const TextStyle(
                                fontFamily: AppConsts.expoArabic,
                                color: Colors.grey,
                                fontSize: 13, // Smaller label
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatDuration(_timeToNext),
                              style: TextStyle(
                                fontFamily: 'Courier',
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyLarge?.color,
                                fontSize: 30, // Slightly smaller
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Stack Dates Vertically to prevent overlap
                            Text(
                              hijriStr,
                              style: const TextStyle(
                                fontFamily: AppConsts.expoArabic,
                                color: _goldColor,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              gregStr,
                              style: const TextStyle(
                                fontFamily: AppConsts.expoArabic,
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    itemCount:
                        _prayers.length +
                        _tomorrowPrayers.length +
                        2, // +2 for Today header + Tomorrow header
                    itemBuilder: (context, index) {
                      // Section 0: Today's date header
                      if (index == 0) {
                        final todayDate = DateTime.now();
                        final todayStr = DateFormat(
                          'EEEE d MMMM yyyy',
                          'ar',
                        ).format(todayDate);
                        return _buildDateHeader(todayStr);
                      }

                      // Section 1: Today's prayers
                      if (index <= _prayers.length) {
                        final p = _prayers[index - 1];
                        final isNext = p == _nextPrayer;
                        return _buildPrayerRow(p, isNext);
                      }

                      // Section 2: Tomorrow's date header
                      if (index == _prayers.length + 1) {
                        final tomorrowDate = DateTime.now().add(
                          const Duration(days: 1),
                        );
                        final tomorrowStr = DateFormat(
                          'EEEE d MMMM yyyy',
                          'ar',
                        ).format(tomorrowDate);
                        return _buildDateHeader(tomorrowStr);
                      }

                      // Section 3: Tomorrow's prayers
                      final p = _tomorrowPrayers[index - _prayers.length - 2];
                      final isNext = p == _nextPrayer;
                      return _buildPrayerRow(p, isNext);
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDateHeader(String dateText) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          const Expanded(child: Divider(color: _goldColor)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              dateText,
              style: const TextStyle(
                fontFamily: AppConsts.expoArabic,
                color: _goldColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Expanded(child: Divider(color: _goldColor)),
        ],
      ),
    );
  }

  Widget _buildPrayerRow(ExtendedPrayer p, bool isActive) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rowBgColor = isActive
        ? _goldColor
        : (isDark ? const Color(0xFF1E1E1E) : Colors.white);
    final rowTextColor = isActive
        ? Colors.black
        : (isDark ? Colors.white : Colors.black);
    final timeColor = isActive ? Colors.black : _goldColor;

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (_) => PrayerDetailModal(prayer: p),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: rowBgColor,
          borderRadius: BorderRadius.circular(15),
          border: isActive
              ? null
              : Border.all(
                  color: isDark ? Colors.white10 : Colors.grey.withAlpha(50),
                ),
          boxShadow: isActive || !isDark
              ? [
                  BoxShadow(
                    color: Colors.grey.withAlpha(20),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                p.name,
                style: TextStyle(
                  fontFamily: AppConsts.expoArabic,
                  color: rowTextColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Row(
              children: [
                if (isActive) ...[
                  Icon(
                    Icons.timer,
                    size: 16,
                    color: Colors.black.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    "القادمة",
                    style: TextStyle(
                      fontFamily: AppConsts.expoArabic,
                      color: Colors.black.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Text(
                  PrayerService().formatTime(p.time),
                  style: TextStyle(
                    fontFamily: AppConsts.expoArabic,
                    color: timeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
