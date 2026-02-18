import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
// For PrayerTime types or calculations if needed to show "Current Time"

class AdjustmentScreen extends StatefulWidget {
  const AdjustmentScreen({super.key});

  @override
  State<AdjustmentScreen> createState() => _AdjustmentScreenState();
}

class _AdjustmentScreenState extends State<AdjustmentScreen> {
  late SharedPreferences _prefs;
  bool _isLoading = true;

  // Offsets and Iqama mins map
  final Map<String, int> _adhanOffsets = {
    'fajr': 0,
    'dhuhr': 0,
    'asr': 0,
    'maghrib': 0,
    'isha': 0,
  };
  final Map<String, int> _iqamaMinutes = {
    'fajr': 20,
    'dhuhr': 20,
    'asr': 20,
    'maghrib': 10,
    'isha': 20,
  };

  // Prayers List
  final List<String> _prayers = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
  final Map<String, String> _prayerNames = {
    'fajr': "الفجر",
    'dhuhr': "الظهر",
    'asr': "العصر",
    'maghrib': "المغرب",
    'isha': "العشاء",
  };

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      for (var p in _prayers) {
        _adhanOffsets[p] = _prefs.getInt('${p}_offset') ?? 0;
        _iqamaMinutes[p] = _prefs.getInt('${p}_iqama') ?? 20;
      }
      _isLoading = false;
    });
  }

  Future<void> _updateOffset(String prayer, int delta) async {
    int current = _adhanOffsets[prayer]!;
    int newVal = current + delta;
    // Limit reasonable offset e.g. -60 to +60
    if (newVal < -60 || newVal > 60) return;

    await _prefs.setInt('${prayer}_offset', newVal);
    setState(() {
      _adhanOffsets[prayer] = newVal;
    });
    // Trigger Service Update if needed (usually auto-read on next build/fetch)
  }

  Future<void> _updateIqama(String prayer, int delta) async {
    int current = _iqamaMinutes[prayer]!;
    int newVal = current + delta;
    if (newVal < 1) return; // Min 1 minute

    await _prefs.setInt('${prayer}_iqama', newVal);
    setState(() {
      _iqamaMinutes[prayer] = newVal;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          "ضبط مواقيت الأذان والإقامة",
          style: TextStyle(
            fontFamily: AppConsts.expoArabic,
            color: Color(0xFFD0A871),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFFD0A871)),
      ),
      body: ListView.builder(
        padding: EdgeInsets.all(16.w),
        itemCount: _prayers.length,
        itemBuilder: (context, index) {
          return _buildPrayerCard(_prayers[index]);
        },
      ),
    );
  }

  Widget _buildPrayerCard(String key) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E), // Dark Grey
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _prayerNames[key]!,
                style: TextStyle(
                  fontFamily: AppConsts.expoArabic,
                  color: const Color(0xFFD0A871),
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // Could show calculated time here if we passed PrayerTimes
            ],
          ),
          Divider(color: Colors.white10, height: 20.h),

          // Row 1: Adhan Offset
          _buildControlRow(
            "تعديل الأذان (دقائق)",
            _adhanOffsets[key]!,
            (val) => _updateOffset(key, val),
          ),

          SizedBox(height: 10.h),

          // Row 2: Iqama Time
          _buildControlRow(
            "وقت الإقامة (بعد الأذان)",
            _iqamaMinutes[key]!,
            (val) => _updateIqama(key, val),
            isIqama: true,
          ),
        ],
      ),
    );
  }

  Widget _buildControlRow(
    String label,
    int value,
    Function(int) onChange, {
    bool isIqama = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: AppConsts.expoArabic,
            color: Colors.white70,
            fontSize: 14.sp,
          ),
        ),
        Row(
          children: [
            _buildCircleBtn(Icons.remove, () => onChange(-1)),
            SizedBox(width: 10.w),
            SizedBox(
              width: 40.w,
              child: Text(
                "$value",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppConsts.expoArabic,
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(width: 10.w),
            _buildCircleBtn(Icons.add, () => onChange(1)),
          ],
        ),
      ],
    );
  }

  Widget _buildCircleBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.all(5.w),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFD0A871)),
          color: Colors.transparent,
        ),
        child: Icon(icon, color: const Color(0xFFD0A871), size: 18.w),
      ),
    );
  }
}
