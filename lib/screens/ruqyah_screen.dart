import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ضروري عشان النسخ Clipboard
import 'dart:convert';
import 'package:ibad_al_rahmann/core/app_constants.dart';

class RuqyahScreen extends StatefulWidget {
  const RuqyahScreen({super.key});

  @override
  State<RuqyahScreen> createState() => _RuqyahScreenState();
}

class _RuqyahScreenState extends State<RuqyahScreen> {
  Future<List<dynamic>> loadRuqyah() async {
    try {
      String jsonString = await rootBundle.loadString(
        'assets/data/ruqyah.json',
      );
      return json.decode(jsonString);
    } catch (e) {
      debugPrint("خطأ في تحميل الرقية: $e");
      return [];
    }
  }

  // دالة النسخ
  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "تم نسخ النص بنجاح",
          style: TextStyle(fontFamily: AppConsts.expoArabic),
        ),
        backgroundColor: Color(0xFFD0A871),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'الرقية الشرعية',
          style: TextStyle(
            fontFamily: AppConsts.expoArabic,
            fontWeight: FontWeight.bold,
            color: Color(0xFF3E2723),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF3E2723)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF2D69D), Color(0xFFD0A871), Color(0xFFB88A4A)],
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
          ),
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<List<dynamic>>(
          future: loadRuqyah(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFFD0A871)),
              );
            } else if (snapshot.hasError ||
                !snapshot.hasData ||
                snapshot.data!.isEmpty) {
              return Center(
                child: Text(
                  "لا توجد بيانات",
                  style: TextStyle(
                    fontFamily: AppConsts.expoArabic,
                    color: textColor,
                  ),
                ),
              );
            }

            final ruqyahList = snapshot.data!;

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(15, 10, 15, 15),
              physics: const BouncingScrollPhysics(),
              itemCount: ruqyahList.length,
              itemBuilder: (context, index) {
                final item = ruqyahList[index];
                final text =
                    item['zekr'] ??
                    item['ARABIC_TEXT'] ??
                    item['content'] ??
                    '';

                return Container(
                  margin: const EdgeInsets.only(bottom: 15),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                    border: Border.all(
                      color: const Color(0xFFD0A871),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        text,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppConsts.amiri,
                          fontSize: 22,
                          height: 1.8,
                          color: textColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      const SizedBox(height: 15),
                      Divider(
                        color: const Color(0xFFD0A871).withValues(alpha: 0.3),
                      ),

                      // زر النسخ الجديد
                      InkWell(
                        onTap: () => _copyToClipboard(text),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFD0A871,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "نسخ",
                                style: TextStyle(
                                  fontFamily: AppConsts.expoArabic,
                                  color: Color(0xFFD0A871),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(
                                Icons.copy,
                                color: Color(0xFFD0A871),
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
