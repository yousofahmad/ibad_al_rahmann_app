import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../bloc/khatma_cubit.dart';
import '../utils/wird_calculator.dart';

class NewKhatmaScreen extends StatefulWidget {
  const NewKhatmaScreen({super.key});

  @override
  State<NewKhatmaScreen> createState() => _NewKhatmaScreenState();
}

class _NewKhatmaScreenState extends State<NewKhatmaScreen> {
  // Mode selection
  bool _isByAmount = false;

  // Simple duration selection
  int _totalDays = 30; // 1 to 365

  // Amount selection
  int _amountValue = 1;
  WirdUnit _selectedUnit = WirdUnit.page;

  int _startJuz = 1;
  int _startPage = 1; // For page-based start selection (1-604)
  bool _startByJuz = true; // Toggle: start by juz or page
  String _reminderType = 'none'; // none, daily, prayer

  // Daily reminder time
  TimeOfDay _dailyTime = const TimeOfDay(hour: 20, minute: 0);

  // Custom Adhan delay (minutes after prayer for Wird notification)
  int _adhanDelayMinutes = 20;

  bool _isLoading = false;

  /// Remaining pages from startJuz
  int get _remainingPages => WirdCalculator.getRemainingPages(_startJuz);

  /// Pages per day, dynamically computed based on mode and reminder type
  int get _pagesPerDay {
    if (!_isByAmount) {
      // سرعة القراءة الأساسية: بنقسم المصحف كامل على المدة اللي اختارها
      return (604 / _totalDays).ceil();
    }
    // Amount mode: depends on whether daily or per-prayer
    bool isPerPrayer = _reminderType == 'prayer';
    return WirdCalculator.getPagesPerDay(
      amount: _amountValue,
      unit: _selectedUnit,
      isPerPrayer: isPerPrayer,
    );
  }

  /// Effective start page based on toggle
  int get _effectiveStartPage {
    if (_startByJuz) {
      return WirdCalculator.juzStartPages[_startJuz - 1];
    }
    return _startPage;
  }

  /// Total estimated days dynamically calculated
  int get _estimatedDays {
    if (!_isByAmount) {
      int remaining = 604 - _effectiveStartPage + 1;
      int ppd = _pagesPerDay;
      if (ppd <= 0) ppd = 1;
      return (remaining / ppd).ceil();
    }

    // Amount mode logic...
    if (_selectedUnit == WirdUnit.juz) {
      int remainingJuzs = 31 - _startJuz;
      return (remainingJuzs / _amountValue).ceil();
    } else if (_selectedUnit == WirdUnit.quarter) {
      // 8 quarters per juz, 240 total
      int totalQuarters = (31 - _startJuz) * 8;
      return (totalQuarters / _amountValue).ceil();
    } else {
      // Pages
      int remaining = 604 - _effectiveStartPage + 1;
      int ppd = _pagesPerDay;
      if (ppd <= 0) ppd = 1;
      return (remaining / ppd).ceil();
    }
  }

  /// Whether "Distribute over prayers" should be enabled
  /// (disabled if less than 5 pages per day)
  bool get _canDistributeOverPrayers {
    if (!_isByAmount) {
      // الاعتماد المباشر على سرعة القراءة الجديدة الموحدة
      return _pagesPerDay >= 5;
    }
    // In amount mode, calculate what the per-prayer setting would give
    int ppdIfPrayer = WirdCalculator.getPagesPerDay(
      amount: _amountValue,
      unit: _selectedUnit,
      isPerPrayer: true,
    );
    return ppdIfPrayer >= 5;
  }

  /// Estimated total wirds
  int get _estimatedWirds {
    return _reminderType == 'prayer' ? _estimatedDays * 5 : _estimatedDays;
  }

  void _pickDailyTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dailyTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: const Color(0xFFD0A871)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _dailyTime = picked);
    }
  }

  void _startKhatma() async {
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();

    // Save daily time if needed
    if (_reminderType == 'daily') {
      final timeStr =
          '${_dailyTime.hour.toString().padLeft(2, '0')}:${_dailyTime.minute.toString().padLeft(2, '0')}';
      await prefs.setString('wird_daily_time', timeStr);
    }

    // Save custom adhan delay
    await prefs.setInt('wird_adhan_delay_minutes', _adhanDelayMinutes);

    // Determine start parameters
    await context.read<KhatmaCubit>().startNewKhatma(
      totalDays: _estimatedDays,
      unit: _isByAmount ? _selectedUnit : WirdUnit.page,
      notificationType: _reminderType,
      startJuz: _startByJuz ? _startJuz : 1,
      startFromPage: _startByJuz ? null : _startPage,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("تم بدء الختمة بنجاح!"),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : const Color(0xFFF5F5F5);
    final textColor = isDark ? Colors.white : Colors.black87;
    const goldColor = Color(0xFFD0A871);

    // Auto-disable prayer distribution if not enough pages
    if (_reminderType == 'prayer' && !_canDistributeOverPrayers) {
      _reminderType = 'daily';
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          "بدء ختمة جديدة",
          style: TextStyle(
            color: goldColor,
            fontFamily: AppConsts.expoArabic,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: goldColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ═══ Mode Selection ═══
            Container(
              decoration: BoxDecoration(
                color: goldColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isByAmount = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: !_isByAmount ? goldColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Center(
                          child: Text(
                            "الختمة بالمدة",
                            style: TextStyle(
                              color: !_isByAmount ? Colors.black : goldColor,
                              fontWeight: FontWeight.bold,
                              fontFamily: AppConsts.cairo,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isByAmount = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _isByAmount ? goldColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Center(
                          child: Text(
                            "الختمة بالكمية",
                            style: TextStyle(
                              color: _isByAmount ? Colors.black : goldColor,
                              fontWeight: FontWeight.bold,
                              fontFamily: AppConsts.cairo,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ═══ المـدة / الكمية ═══
            _buildCard(
              context: context,
              title: _isByAmount ? "كمية القراءة" : "مدة الختمة المُرادة",
              icon: _isByAmount
                  ? FontAwesomeIcons.bookOpenReader
                  : FontAwesomeIcons.stopwatch,
              child: Column(
                children: [
                  const SizedBox(height: 10),

                  if (!_isByAmount)
                    _buildQuantityRow(
                      value: _estimatedDays,
                      min: 1,
                      max: 365,
                      suffix: "$_estimatedDays يوم",
                      onChanged: (v) {
                        setState(() {
                          // نحسب سرعة القراءة المطلوبة لإنهاء المتبقي في v يوم
                          double requiredSpeed = _remainingPages / v;
                          // الآن نضبط _totalDays بحيث تعطينا هذه السرعة للمصحف كامل
                          if (requiredSpeed > 0) {
                            _totalDays = (604 / requiredSpeed).round();
                          }
                          // حدود الأمان للـ _totalDays
                          if (_totalDays < 1) _totalDays = 1;
                          if (_totalDays > 1000) _totalDays = 1000;
                        });
                      },
                      goldColor: goldColor,
                    )
                  else
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            DropdownButton<WirdUnit>(
                              value: _selectedUnit,
                              dropdownColor: isDark
                                  ? Colors.grey[900]
                                  : Colors.white,
                              style: TextStyle(
                                color: textColor,
                                fontFamily: AppConsts.cairo,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              underline: const SizedBox(),
                              items: const [
                                DropdownMenuItem(
                                  value: WirdUnit.page,
                                  child: Text("صفحات"),
                                ),
                                DropdownMenuItem(
                                  value: WirdUnit.quarter,
                                  child: Text("أرباع"),
                                ),
                                DropdownMenuItem(
                                  value: WirdUnit.juz,
                                  child: Text("أجزاء"),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedUnit = val);
                                }
                              },
                            ),
                            const SizedBox(width: 16),
                            _buildQuantityRow(
                              value: _amountValue,
                              min: 1,
                              max: 20,
                              suffix: "$_amountValue",
                              onChanged: (v) =>
                                  setState(() => _amountValue = v),
                              goldColor: goldColor,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Context label showing what the amount means
                        Text(
                          _reminderType == 'prayer'
                              ? "بعد كل صلاة (×٥ يومياً)"
                              : "يومياً",
                          style: TextStyle(
                            color: goldColor.withValues(alpha: 0.7),
                            fontSize: 13,
                            fontFamily: AppConsts.cairo,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ═══ نقطة البداية ═══
            _buildCard(
              context: context,
              title: "نقطة البداية",
              icon: FontAwesomeIcons.bookOpen,
              child: Column(
                children: [
                  // Toggle: start by juz or page
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: goldColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _startByJuz = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _startByJuz
                                    ? goldColor
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  "بالجزء",
                                  style: TextStyle(
                                    color: _startByJuz
                                        ? Colors.black
                                        : goldColor,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: AppConsts.cairo,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _startByJuz = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: !_startByJuz
                                    ? goldColor
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  "بالصفحة",
                                  style: TextStyle(
                                    color: !_startByJuz
                                        ? Colors.black
                                        : goldColor,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: AppConsts.cairo,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (_startByJuz) ...[
                    // Pick starting juz
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "ابدأ القراءة من:",
                          style: TextStyle(fontSize: 16),
                        ),
                        DropdownButton<int>(
                          value: _startJuz,
                          dropdownColor: isDark
                              ? Colors.grey[900]
                              : Colors.white,
                          style: TextStyle(
                            color: textColor,
                            fontFamily: AppConsts.cairo,
                            fontWeight: FontWeight.bold,
                          ),
                          underline: const SizedBox(),
                          items: List.generate(30, (index) => index + 1).map((
                            juz,
                          ) {
                            return DropdownMenuItem<int>(
                              value: juz,
                              child: Text("الجزء $juz"),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _startJuz = val);
                            }
                          },
                        ),
                      ],
                    ),
                    if (_startJuz > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          "صفحات متبقية: $_remainingPages من 604",
                          style: TextStyle(
                            color: goldColor.withValues(alpha: 0.7),
                            fontSize: 13,
                            fontFamily: AppConsts.cairo,
                          ),
                        ),
                      ),
                  ] else ...[
                    // Pick starting page number
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "ابدأ من صفحة:",
                          style: TextStyle(fontSize: 16),
                        ),
                        _buildQuantityRow(
                          value: _startPage,
                          min: 1,
                          max: 604,
                          suffix: "$_startPage",
                          onChanged: (v) => setState(() => _startPage = v),
                          goldColor: goldColor,
                        ),
                      ],
                    ),
                    if (_startPage > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          "صفحات متبقية: ${604 - _startPage + 1} من 604",
                          style: TextStyle(
                            color: goldColor.withValues(alpha: 0.7),
                            fontSize: 13,
                            fontFamily: AppConsts.cairo,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ═══ نظام التذكير ═══
            _buildCard(
              context: context,
              title: "نظام التذكير",
              icon: FontAwesomeIcons.bell,
              child: Column(
                children: [
                  RadioListTile<String>(
                    title: const Text("بدون تذكير"),
                    value: 'none',
                    groupValue: _reminderType,
                    activeColor: goldColor,
                    onChanged: (v) => setState(() => _reminderType = v!),
                  ),
                  RadioListTile<String>(
                    title: const Text("تذكير يومي للورد"),
                    value: 'daily',
                    groupValue: _reminderType,
                    activeColor: goldColor,
                    onChanged: (v) => setState(() => _reminderType = v!),
                  ),
                  // Show time picker when daily is selected
                  if (_reminderType == 'daily')
                    Padding(
                      padding: const EdgeInsets.only(right: 32, bottom: 8),
                      child: InkWell(
                        onTap: _pickDailyTime,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: goldColor.withValues(alpha: 0.3),
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.access_time,
                                color: goldColor,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "الساعة ${_dailyTime.hour.toString().padLeft(2, '0')}:${_dailyTime.minute.toString().padLeft(2, '0')}",
                                style: const TextStyle(
                                  color: goldColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.edit,
                                color: goldColor.withValues(alpha: 0.5),
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  // Distribute over prayers — only enabled if >= 5 pages/day
                  RadioListTile<String>(
                    title: Text(
                      "توزيع بعد الصلوات",
                      style: TextStyle(
                        color: _canDistributeOverPrayers ? null : Colors.grey,
                      ),
                    ),
                    subtitle: !_canDistributeOverPrayers
                        ? Text(
                            "يتطلب ٥ صفحات على الأقل يومياً",
                            style: TextStyle(
                              color: Colors.red.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          )
                        : (_reminderType == 'prayer'
                              ? Text(
                                  "كل صلاة = جزء من الورد اليومي",
                                  style: TextStyle(
                                    color: goldColor.withValues(alpha: 0.7),
                                    fontSize: 12,
                                  ),
                                )
                              : null),
                    value: 'prayer',
                    groupValue: _reminderType,
                    activeColor: goldColor,
                    onChanged: _canDistributeOverPrayers
                        ? (v) => setState(() => _reminderType = v!)
                        : null,
                  ),
                  // Custom Adhan delay setting (only for prayer mode)
                  if (_reminderType == 'prayer')
                    Padding(
                      padding: const EdgeInsets.only(
                        right: 32,
                        left: 16,
                        bottom: 8,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.timer_outlined,
                              color: goldColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "تأخير بعد الأذان: ",
                              style: TextStyle(
                                color: textColor,
                                fontFamily: AppConsts.cairo,
                                fontSize: 14,
                              ),
                            ),
                            _buildQuantityRow(
                              value: _adhanDelayMinutes,
                              min: 5,
                              max: 60,
                              suffix: "$_adhanDelayMinutes د",
                              onChanged: (v) =>
                                  setState(() => _adhanDelayMinutes = v),
                              goldColor: goldColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ═══ Summary ═══
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: goldColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: goldColor.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        FontAwesomeIcons.calendarDay,
                        color: goldColor,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "ختمة في $_estimatedDays يوم",
                        style: const TextStyle(
                          color: goldColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "~$_pagesPerDay صفحة يومياً",
                    style: TextStyle(
                      color: goldColor.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                  ),
                  if (_reminderType == 'prayer') ...[
                    const SizedBox(height: 4),
                    Text(
                      "$_estimatedWirds ورد ($_estimatedDays يوم × ٥ صلوات)",
                      style: TextStyle(
                        color: goldColor.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 30),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: goldColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              onPressed: _isLoading ? null : _startKhatma,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.black)
                  : const Text(
                      "بدء الختمة",
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

  Widget _buildQuantityRow({
    required int value,
    required int min,
    required int max,
    required String suffix,
    required ValueChanged<int> onChanged,
    required Color goldColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          color: goldColor,
          iconSize: 22,
          constraints: const BoxConstraints(),
          padding: const EdgeInsets.all(4),
          onPressed: value > min ? () => onChanged(value - 1) : null,
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: goldColor.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            suffix,
            style: TextStyle(
              color: goldColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          color: goldColor,
          iconSize: 22,
          constraints: const BoxConstraints(),
          padding: const EdgeInsets.all(4),
          onPressed: value < max ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }

  Widget _buildCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const goldColor = Color(0xFFD0A871);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FaIcon(icon, color: goldColor, size: 18),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: goldColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          child,
        ],
      ),
    );
  }
}
