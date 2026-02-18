import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:ibad_al_rahmann/services/prayer_service.dart';
import 'package:ibad_al_rahmann/features/locations/models/city_profile.dart';
import 'city_config_screen.dart';
import 'package:uuid/uuid.dart';

class LocationsListScreen extends StatefulWidget {
  const LocationsListScreen({super.key});

  @override
  State<LocationsListScreen> createState() => _LocationsListScreenState();
}

class _LocationsListScreenState extends State<LocationsListScreen> {
  final PrayerService _service = PrayerService();

  void _refresh() {
    setState(() {});
  }

  void _addCityPlaceholder() async {
    // Ideally this opens a Search Screen.
    // For now, we add a placeholder "New City" or "Mecca" test
    // Or show a minimal dialog to enter name/coords.

    // Quick Add Mock
    final newCity = CityProfile(
      id: const Uuid().v4(),
      name: "مكة المكرمة ${DateTime.now().second}", // Unique name for test
      latitude: 21.4225,
      longitude: 39.8262,
      calculationMethod: 'makkah',
    );
    await _service.addCity(newCity);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final cities = _service.savedCities;
    final activeId = _service.activeCity?.id;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          "المواقع والمدن",
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
      floatingActionButton: FloatingActionButton(
        onPressed: _addCityPlaceholder,
        backgroundColor: const Color(0xFFD0A871),
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: cities.isEmpty ? _buildEmptyState() : _buildList(cities, activeId),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_on_outlined,
            size: 80.w,
            color: const Color(0xFFD0A871).withValues(alpha: 0.5),
          ),
          SizedBox(height: 16.h),
          Text(
            "لم يتم إضافة أي مدينة",
            style: TextStyle(
              fontFamily: AppConsts.expoArabic,
              color: Colors.white54,
              fontSize: 16.sp,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            "اضغط على + لإضافة موقع جديد",
            style: TextStyle(
              fontFamily: AppConsts.expoArabic,
              color: Colors.grey,
              fontSize: 12.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<CityProfile> cities, String? activeId) {
    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: cities.length,
      itemBuilder: (context, index) {
        final city = cities[index];
        final isActive = city.id == activeId;

        return GestureDetector(
          onTap: () async {
            await _service.setActiveCity(city.id);
            _refresh();
          },
          child: Container(
            margin: EdgeInsets.only(bottom: 12.h),
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: const Color(0xFF121212),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: isActive ? const Color(0xFFD0A871) : Colors.white10,
                width: isActive ? 1.5 : 1,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: const Color(0xFFD0A871).withValues(alpha: 0.2),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ]
                  : [],
            ),
            child: Row(
              children: [
                // Active Indicator Icon
                Icon(
                  isActive ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: isActive ? const Color(0xFFD0A871) : Colors.grey,
                ),
                SizedBox(width: 16.w),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        city.name,
                        style: TextStyle(
                          fontFamily: AppConsts.expoArabic,
                          color: Colors.white,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "${city.latitude.toStringAsFixed(2)}, ${city.longitude.toStringAsFixed(2)}",
                        style: TextStyle(
                          fontFamily: AppConsts.expoArabic,
                          color: Colors.grey,
                          fontSize: 12.sp,
                        ),
                      ),
                    ],
                  ),
                ),

                // Edit Button
                IconButton(
                  icon: const Icon(Icons.settings, color: Color(0xFFD0A871)),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CityConfigScreen(city: city),
                      ),
                    );
                    _refresh();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
