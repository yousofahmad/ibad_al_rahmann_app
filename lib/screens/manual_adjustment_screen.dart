import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ibad_al_rahmann/services/prayer_service.dart';

class ManualAdjustmentScreen extends StatefulWidget {
  const ManualAdjustmentScreen({super.key});

  @override
  State<ManualAdjustmentScreen> createState() => _ManualAdjustmentScreenState();
}

class _ManualAdjustmentScreenState extends State<ManualAdjustmentScreen> {
  final PrayerService _prayerService = PrayerService();

  // Data holders
  final Map<String, int> _adhanAdjustments = {};
  final Map<String, int> _iqamaAdjustments = {};

  final List<String> _prayers = [
    'Fajr',
    'Sunrise',
    'Dhuhr',
    'Asr',
    'Maghrib',
    'Isha',
  ];
  final Map<String, String> _prayerNames = {
    'Fajr': 'الفجر',
    'Sunrise': 'الشروق',
    'Dhuhr': 'الظهر',
    'Asr': 'العصر',
    'Maghrib': 'المغرب',
    'Isha': 'العشاء',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      for (var p in _prayers) {
        // Adhan: standard adjustment keys from PrayerService
        _adhanAdjustments[p] = prefs.getInt('adjust_$p') ?? 0;

        // Iqama: keys used by NotificationService 'iqama_minutes_$key'
        // Default Iqama times: Maghrib 10, Fajr 20, others 15.
        // Sunrise has no Iqama.
        int def = (p == 'Maghrib' ? 10 : (p == 'Fajr' ? 20 : 15));
        _iqamaAdjustments[p] = prefs.getInt('iqama_minutes_$p') ?? def;
      }
    });
  }

  Future<void> _saveAdhan(String prayer, int val) async {
    await _prayerService.saveAdjustment(prayer, val);
    setState(() => _adhanAdjustments[prayer] = val);
  }

  Future<void> _saveIqama(String prayer, int val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('iqama_minutes_$prayer', val);
    setState(() => _iqamaAdjustments[prayer] = val);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "تعديل الأوقات يدويًا",
          style: TextStyle(
            color: Color(0xFFD0A871),
            fontFamily: 'Cairo',
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFFD0A871)
              : Colors.black,
        ),
      ),
      body: ListView.builder(
        padding: EdgeInsets.all(16.w),
        itemCount: _prayers.length,
        itemBuilder: (context, index) {
          final prayer = _prayers[index];
          final hasIqama = prayer != 'Sunrise';

          return Container(
            margin: EdgeInsets.only(bottom: 16.h),
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Prayer Name
                Text(
                  _prayerNames[prayer]!,
                  style: TextStyle(
                    color: const Color(0xFFD0A871),
                    fontSize: 18.sp,
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16.h),

                // Adhan Row
                _buildControlRow(
                  "تعديل الأذان (دقائق)",
                  _adhanAdjustments[prayer] ?? 0,
                  (val) => _saveAdhan(prayer, val),
                ),

                if (hasIqama) ...[
                  Divider(color: Colors.white10, height: 24.h),
                  // Iqama Row
                  _buildControlRow(
                    "وقت الإقامة (دقائق)",
                    _iqamaAdjustments[prayer] ?? 15,
                    (val) => _saveIqama(prayer, val),
                    minVal: 1, // Iqama can't be negative generally
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildControlRow(
    String label,
    int value,
    Function(int) onChanged, {
    int minVal = -60,
  }) {
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: textColor.withValues(alpha: 0.7),
            fontFamily: 'Cairo',
            fontSize: 14.sp,
          ),
        ),
        Row(
          children: [
            _buildBtn(Icons.remove, () {
              if (value > minVal) onChanged(value - 1);
            }),
            SizedBox(width: 12.w),
            SizedBox(
              width: 40.w,
              child: Text(
                "$value",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor,
                  fontFamily: 'Cairo',
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(width: 12.w),
            _buildBtn(Icons.add, () {
              if (value < 60) onChanged(value + 1);
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildBtn(IconData icon, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFFD0A871).withValues(alpha: 0.5),
          ),
        ),
        child: Icon(icon, color: const Color(0xFFD0A871), size: 20),
      ),
    );
  }
}
