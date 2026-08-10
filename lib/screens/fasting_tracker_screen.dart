import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../widgets/app_skeleton.dart';
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';

class FastingTrackerScreen extends StatefulWidget {
  const FastingTrackerScreen({super.key});

  @override
  State<FastingTrackerScreen> createState() => _FastingTrackerScreenState();
}

class _FastingTrackerScreenState extends State<FastingTrackerScreen> {
  // Key format: 'fasting_yyyy-MM-dd'
  final Map<String, bool> _fastedDays = {};
  bool _isLoading = true;
  DateTime _focusedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadMonthData();
  }

  Future<void> _loadMonthData() async {
    setState(() => _isLoading = true);
    final prefs = CacheHelper.prefs;

    // Load data for current month (approximated range)
    // Actually we can just check existence of keys when building
    // But to show stats we need to count total keys?
    // Let's just load on demand in build or maintain a list.
    // simpler: _loadKeys
    final keys = prefs
        .getKeys()
        .where((k) => k.startsWith('fasting_'))
        .toList();
    _fastedDays.clear();
    for (String k in keys) {
      if (prefs.getBool(k) == true) {
        // k is 'fasting_2024-01-20'
        _fastedDays[k.replaceAll('fasting_', '')] = true;
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _toggleDay(DateTime day) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(day.year, day.month, day.day);

    if (target.isAfter(today)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("لا يمكن تسجيل الصيام لموعد في المستقبل!"),
        ),
      );
      return;
    }

    final key = DateFormat('yyyy-MM-dd').format(target);
    final isFasted = _fastedDays[key] ?? false;
    final newValue = !isFasted;

    setState(() {
      if (newValue) {
        _fastedDays[key] = true;
      } else {
        _fastedDays.remove(key);
      }
    });

    final prefs = CacheHelper.prefs;
    await prefs.setBool('fasting_$key', newValue);
  }

  @override
  Widget build(BuildContext context) {
    // Generate days for focused month
    final daysInMonth = DateUtils.getDaysInMonth(
      _focusedDay.year,
      _focusedDay.month,
    );
    final firstDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final weekdayOffset =
        firstDayOfMonth.weekday % 7; // Su=0, Mo=1... adjust for Grid

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          "سجل الصيام",
          style: TextStyle(color: Color(0xFFD0A871), fontFamily: 'Cairo'),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Color(0xFFD0A871)),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    "تم حفظ سجل الصيام بنجاح 💾",
                    style: TextStyle(fontFamily: 'Cairo'),
                  ),
                  backgroundColor: Color(0xFFD0A871),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.today),
            onPressed: () {
              setState(() => _focusedDay = DateTime.now());
            },
          ),
        ],
      ),
      body: _isLoading
          ? GridView.builder(
              padding: EdgeInsets.all(16.w),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
              ),
              itemCount: 35,
              itemBuilder: (_, __) => AppSkeleton(width: 40.w, height: 40.w, borderRadius: 20),
            )
          : Column(
              children: [
                // Month Navigation
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 8.h,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          setState(() {
                            _focusedDay = DateTime(
                              _focusedDay.year,
                              _focusedDay.month - 1,
                            );
                          });
                        },
                      ),
                      Text(
                        DateFormat('MMMM yyyy', 'ar').format(_focusedDay),
                        key: ValueKey(
                          _focusedDay.month + _focusedDay.year * 12,
                        ),
                        style: TextStyle(
                          color: const Color(0xFFD0A871),
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          setState(() {
                            _focusedDay = DateTime(
                              _focusedDay.year,
                              _focusedDay.month + 1,
                            );
                          });
                        },
                      ),
                    ],
                  ),
                ),

                // Days Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children:
                      [
                            "الأحد",
                            "الاثنين",
                            "الثلاثاء",
                            "الأربعاء",
                            "الخميس",
                            "الجمعة",
                            "السبت",
                          ]
                          .map(
                            (d) => Text(
                              d,
                              style: const TextStyle(color: Colors.grey),
                            ),
                          )
                          .toList(),
                ),
                SizedBox(height: 10.h),

                // Calendar Grid
                Expanded(
                  child: GridView.builder(
                    padding: EdgeInsets.all(16.w),
                    gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 8.h,
                          crossAxisSpacing: 8.w,
                        ),
                    itemCount: daysInMonth + weekdayOffset,
                    itemBuilder: (context, index) {
                      if (index < weekdayOffset) return const SizedBox();

                      final dayNum = index - weekdayOffset + 1;
                      final currentDay = DateTime(
                        _focusedDay.year,
                        _focusedDay.month,
                        dayNum,
                      );
                      final key = DateFormat('yyyy-MM-dd').format(currentDay);
                      final isFasted = _fastedDays[key] ?? false;

                      final isFuture = currentDay.isAfter(DateTime.now());

                      return GestureDetector(
                        onTap: () => _toggleDay(currentDay),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isFasted
                                ? const Color(0xFFD0A871)
                                : (isFuture
                                      ? Colors.grey[900]
                                      : const Color(0xFF000000)),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isFasted
                                  ? Colors.transparent
                                  : Colors.grey[800]!,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              "$dayNum",
                              style: TextStyle(
                                color: isFasted
                                    ? Colors.black
                                    : (isFuture
                                          ? Colors.grey[700]
                                          : Colors.white),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Legend
                Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 16.w,
                        height: 16.h,
                        decoration: const BoxDecoration(
                          color: Color(0xFFD0A871),
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      const Text("صمت", style: TextStyle(color: Colors.white)),
                      SizedBox(width: 24.w),
                      Container(
                        width: 16.w,
                        height: 16.h,
                        decoration: BoxDecoration(
                          color: const Color(0xFF000000),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      const Text(
                        "لم أصم",
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
