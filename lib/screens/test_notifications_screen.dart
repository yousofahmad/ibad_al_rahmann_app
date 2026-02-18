import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:ibad_al_rahmann/services/notification_service.dart';

class TestNotificationsScreen extends StatelessWidget {
  const TestNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          "اختبار التنبيهات (Debug)",
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildTestTile(
            context,
            "تجربة أذان الفجر (100)",
            "Adhan (Group: Prayers)",
            Icons.mosque,
            () => NotificationService.testSpecificNotification('adhan'),
          ),
          _buildTestTile(
            context,
            "تجربة إقامة الصلاة (300)",
            "Iqama (Group: Prayers)",
            Icons.access_time_filled,
            () => NotificationService.testSpecificNotification('iqama'),
          ),
          const Divider(color: Colors.white24),
          _buildTestTile(
            context,
            "مدفع الإفطار (400)",
            "Ramadan (Group: Ramadan)",
            Icons.nightlight_round,
            () => NotificationService.testSpecificNotification('ramadan'),
          ),
          _buildTestTile(
            context,
            "تكبيرات العيد (500)",
            "Eid (Group: Eid)",
            Icons.celebration,
            () => NotificationService.testSpecificNotification('eid'),
          ),
          const Divider(color: Colors.white24),
          _buildTestTile(
            context,
            "أذكار الصباح (1)",
            "Azkar (Group: Azkar)",
            Icons.wb_sunny,
            () => NotificationService.testSpecificNotification('azkar'),
          ),
          _buildTestTile(
            context,
            "الورد اليومي (600)",
            "Wird (Group: Wird)",
            Icons.menu_book,
            () => NotificationService.testSpecificNotification('wird'),
          ),
          const Divider(color: Colors.white24),
          _buildTestTile(
            context,
            "الصلاة على النبي (8000)",
            "Friday (Group: Friday)",
            Icons.favorite,
            () => NotificationService.testSpecificNotification('friday'),
          ),
          const SizedBox(height: 20),
          const Center(
            child: Text(
              "اضغط ثم اخرج من التطبيق فوراً وانتظر 5 ثواني",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestTile(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFFD0A871)),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: AppConsts.expoArabic,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        trailing: const Icon(Icons.touch_app, color: Colors.white54),
        onTap: () {
          onTap();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("تم الجدولة! اخرج من التطبيق الآن وانتظر 5 ثواني"),
              backgroundColor: Color(0xFFD0A871),
              duration: Duration(seconds: 4),
            ),
          );
        },
      ),
    );
  }
}
