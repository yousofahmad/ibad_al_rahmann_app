import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

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
    final prefs = await SharedPreferences.getInstance();

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

    final prefs = await SharedPreferences.getInstance();
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
            icon: const Icon(Icons.today),
            onPressed: () {
              setState(() => _focusedDay = DateTime.now());
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFD0A871)),
            )
          : Column(
              children: [
                // Month Navigation
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
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
                        DateFormat('MMMM yyyy', 'ar').format(
                          _focusedDay,
                        ), // Require locale setup or just en
                        style: const TextStyle(
                          color: Color(0xFFD0A871),
                          fontSize: 20,
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
                const SizedBox(height: 10),

                // Calendar Grid
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
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
                                      : const Color(0xFF1E1E1E)),
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
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: Color(0xFFD0A871),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text("صمت", style: TextStyle(color: Colors.white)),
                      const SizedBox(width: 24),
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey),
                        ),
                      ),
                      const SizedBox(width: 8),
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
