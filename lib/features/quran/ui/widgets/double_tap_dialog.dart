import 'package:flutter/material.dart';
import '../../../../core/app_constants.dart';

class DoubleTapDialog extends StatelessWidget {
  const DoubleTapDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'تلميحات التصفح',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: AppConsts.cairo,
          fontWeight: FontWeight.bold,
          fontSize: 18,
          color: Color(0xFFD0A871),
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHintRow(Icons.touch_app, 'ضغطتين', 'تكبير / تصغير الصفحة'),
          const SizedBox(height: 12),
          _buildHintRow(
            Icons.touch_app_outlined,
            'ضغطة مطولة',
            'التفسير والمشاركة ومشغل الآيات',
          ),
          const SizedBox(height: 12),
          _buildHintRow(
            Icons.bookmark_outline,
            'ضغطة واحدة',
            ' قائمة المحفوظات و تغيير الثيم والمشاركة او الحفظ وضغطة اخري تختفي',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text(
            'حسنًا',
            style: TextStyle(
              color: Color(0xFFD0A871),
              fontFamily: AppConsts.cairo,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHintRow(IconData icon, String title, String desc) {
    return Row(
      textDirection: TextDirection.rtl,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFFD0A871), size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: AppConsts.cairo,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                textDirection: TextDirection.rtl,
              ),
              Text(
                desc,
                style: const TextStyle(
                  fontFamily: AppConsts.cairo,
                  fontSize: 12,
                  color: Colors.grey,
                ),
                textDirection: TextDirection.rtl,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
