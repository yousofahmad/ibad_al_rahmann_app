// Using logo.png as verified. No changes needed if already correct.
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class BubbleScreen extends StatefulWidget {
  const BubbleScreen({super.key});

  @override
  State<BubbleScreen> createState() => _BubbleScreenState();
}

class _BubbleScreenState extends State<BubbleScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // ضروري عشان تبان كدايرة بس
      body: Center(
        child: GestureDetector(
          onTap: () async {
            // 1. لما يدوس عليها، نبعت رسالة للتطبيق الرئيسي
            await FlutterOverlayWindow.shareData("OPEN_AZKAR");
            // 2. نقفل الفقاعة (اختياري، لو عايزها تفضل موجودة شيل السطر ده)
            // await FlutterOverlayWindow.closeOverlay();
          },
          child: Container(
            width: 70, // حجم الدايرة
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFD0A871), // لون ذهبي
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
              // هنا ممكن تحط صورة اللوجو بتاعك
              image: const DecorationImage(
                image: AssetImage('assets/images/logo.png'),
                fit: BoxFit.cover,
              ),
            ),
            // لو الصورة مش موجودة أو لسه، الأيقونة دي هتظهر
            child: const Icon(Icons.touch_app, color: Colors.white, size: 30),
          ),
        ),
      ),
    );
  }
}
