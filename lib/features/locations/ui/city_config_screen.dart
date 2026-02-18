import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:ibad_al_rahmann/features/locations/models/city_profile.dart';
import 'package:ibad_al_rahmann/services/prayer_service.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CityConfigScreen extends StatefulWidget {
  final CityProfile city;

  const CityConfigScreen({super.key, required this.city});

  @override
  State<CityConfigScreen> createState() => _CityConfigScreenState();
}

class _CityConfigScreenState extends State<CityConfigScreen> {
  late String _method;
  late String _madhab;
  late Map<String, int> _offsets;

  @override
  void initState() {
    super.initState();
    _method = widget.city.calculationMethod;
    _madhab = widget.city.madhab;
    _offsets = Map.from(widget.city.offsets);
  }

  Future<void> _save() async {
    CityProfile updated = widget.city.copyWith(
      calculationMethod: _method,
      madhab: _madhab,
      offsets: _offsets,
    );
    await PrayerService().updateCity(updated);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          widget.city.name,
          style: const TextStyle(
            fontFamily: AppConsts.expoArabic,
            color: Color(0xFFD0A871),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFFD0A871)),
        actions: [IconButton(icon: const Icon(Icons.check), onPressed: _save)],
      ),
      body: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          // Section A: General Settings
          _buildSectionHeader("الإعدادات العامة"),
          _buildMethodDropdown(),
          SizedBox(height: 16.h),
          _buildMadhabSwitch(),

          SizedBox(height: 32.h),

          // Section B: Manual Offsets
          _buildSectionHeader("تعديل المواقيت (دقائق)"),
          ..._offsets.keys.map((prayer) => _buildOffsetRow(prayer)),

          SizedBox(height: 32.h),
          _buildDeleteButton(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: AppConsts.expoArabic,
          color: Colors.white,
          fontSize: 18.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMethodDropdown() {
    // Basic mapping, can be expanded
    final methods = {
      'egypt': 'الهيئة المصرية العامة للمساحة',
      'makkah': 'أم القرى (مكة المكرمة)',
      'karachi': 'جامعة العلوم الإسلامية بكراتشي',
      'isna': 'أمريكا الشمالية (ISNA)',
      'mwl': 'رابطة العالم الإسلامي',
      'dubai': 'دبي',
      'kuwait': 'الكويت',
      'qatar': 'قطر',
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: methods.containsKey(_method) ? _method : 'egypt',
          dropdownColor: const Color(0xFF1E1E1E),
          isExpanded: true,
          style: TextStyle(
            fontFamily: AppConsts.expoArabic,
            color: Colors.white,
            fontSize: 14.sp,
          ),
          items: methods.keys.map((key) {
            return DropdownMenuItem(
              value: key,
              child: Text(
                methods[key]!,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _method = val);
          },
        ),
      ),
    );
  }

  Widget _buildMadhabSwitch() {
    bool isHanafi = _madhab == 'hanafi';
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _madhab = 'shafi'),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 10.h),
                decoration: BoxDecoration(
                  color: !isHanafi
                      ? const Color(0xFFD0A871)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(25),
                ),
                alignment: Alignment.center,
                child: Text(
                  "جمهور (شافعي/مالكي/حنبلي)",
                  style: TextStyle(
                    fontFamily: AppConsts.expoArabic,
                    color: !isHanafi ? Colors.black : Colors.white54,
                    fontWeight: FontWeight.bold,
                    fontSize: 12.sp,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _madhab = 'hanafi'),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 10.h),
                decoration: BoxDecoration(
                  color: isHanafi
                      ? const Color(0xFFD0A871)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(25),
                ),
                alignment: Alignment.center,
                child: Text(
                  "حنفي (العصر)",
                  style: TextStyle(
                    fontFamily: AppConsts.expoArabic,
                    color: isHanafi ? Colors.black : Colors.white54,
                    fontWeight: FontWeight.bold,
                    fontSize: 12.sp,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOffsetRow(String prayerKey) {
    // Map internal key to Arabic
    final names = {
      'Fajr': 'الفجر',
      'Sunrise': 'الشروق',
      'Dhuhr': 'الظهر',
      'Asr': 'العصر',
      'Maghrib': 'المغرب',
      'Isha': 'العشاء',
    };

    int val = _offsets[prayerKey] ?? 0;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            names[prayerKey] ?? prayerKey,
            style: TextStyle(
              fontFamily: AppConsts.expoArabic,
              color: Colors.white,
              fontSize: 16.sp,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.remove_circle_outline,
                  color: Color(0xFFD0A871),
                ),
                onPressed: () => setState(() {
                  _offsets[prayerKey] = val - 1;
                }),
              ),
              SizedBox(
                width: 40.w,
                child: Text(
                  "$val",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppConsts.expoArabic,
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: Color(0xFFD0A871),
                ),
                onPressed: () => setState(() {
                  _offsets[prayerKey] = val + 1;
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteButton() {
    return TextButton.icon(
      label: const Text(
        "حذف المدينة",
        style: TextStyle(fontFamily: AppConsts.expoArabic, color: Colors.red),
      ),
      icon: const Icon(Icons.delete, color: Colors.red),
      onPressed: () async {
        // Confirm dialog
        bool? confirm = await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text(
              "حذف المدينة",
              style: TextStyle(
                color: Colors.white,
                fontFamily: AppConsts.expoArabic,
              ),
            ),
            content: const Text(
              "هل أنت متأكد من حذف هذه المدينة؟",
              style: TextStyle(
                color: Colors.white70,
                fontFamily: AppConsts.expoArabic,
              ),
            ),
            actions: [
              TextButton(
                child: const Text(
                  "إلغاء",
                  style: TextStyle(
                    color: Colors.grey,
                    fontFamily: AppConsts.expoArabic,
                  ),
                ),
                onPressed: () => Navigator.pop(context, false),
              ),
              TextButton(
                child: const Text(
                  "حذف",
                  style: TextStyle(
                    color: Colors.red,
                    fontFamily: AppConsts.expoArabic,
                  ),
                ),
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
        );

        if (confirm == true) {
          await PrayerService().removeCity(widget.city.id);
          if (mounted) Navigator.pop(context);
        }
      },
    );
  }
}
