import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';

class BubbleOverlay extends StatefulWidget {
  const BubbleOverlay({super.key});

  @override
  State<BubbleOverlay> createState() => _BubbleOverlayState();
}

class _BubbleOverlayState extends State<BubbleOverlay> {
  bool isMorning() => DateTime.now().hour < 12;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: GestureDetector(
          onTap: () async {
            // فتح التطبيق عند الضغط
            await FlutterOverlayWindow.shareData("open_app");
            // اختياري: إغلاق الفقاعة
            // await FlutterOverlayWindow.closeOverlay();
          },
          child: Container(
            width: 75,
            height: 75,
            decoration: BoxDecoration(
              color: isMorning()
                  ? const Color(0xFFD0A871)
                  : const Color(0xFF2C3E50),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isMorning() ? Icons.wb_sunny : Icons.nights_stay,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(height: 2),
                Text(
                  isMorning() ? "أذكار\nالصباح" : "أذكار\nالمساء",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: AppConsts.expoArabic,
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
