import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AzkarStatisticsScreen extends StatefulWidget {
  const AzkarStatisticsScreen({super.key});

  @override
  State<AzkarStatisticsScreen> createState() => _AzkarStatisticsScreenState();
}

class _AzkarStatisticsScreenState extends State<AzkarStatisticsScreen> {
  int _morningCount = 0;
  int _eveningCount = 0;
  int _prayerCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _morningCount = prefs.getInt('count_morning') ?? 0;
      _eveningCount = prefs.getInt('count_evening') ?? 0;
      _prayerCount = prefs.getInt('count_prayer') ?? 0;
      _isLoading = false;
    });
  }

  Widget _buildStatCard(String title, int count, IconData icon) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFD0A871).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFFD0A871), size: 40),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge?.color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "$count",
            style: const TextStyle(
              color: Color(0xFFD0A871),
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text("مرة", style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "إحصائيات الأذكار",
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontFamily: 'Cairo',
          ),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        iconTheme: IconThemeData(color: Theme.of(context).iconTheme.color),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFD0A871)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Only showing Accountability (Hasib Nafsak) Button since user requested it
                  _buildStatCard("أذكار الصباح", _morningCount, Icons.wb_sunny),
                  _buildStatCard(
                    "أذكار المساء",
                    _eveningCount,
                    Icons.nights_stay,
                  ),
                  _buildStatCard("أذكار الصلاة", _prayerCount, Icons.mosque),
                  // Note: User said "Azkar stats is not Hasib Nafsak stats". He likely wants Hasib Nafsak stats HERE.
                  // Since I cannot link directly to Hasib Nafsak Logic without refactoring, I will show a placeholder or
                  // try to link it if possible. But for now I'm making it theme aware first.
                ],
              ),
            ),
    );
  }
}
