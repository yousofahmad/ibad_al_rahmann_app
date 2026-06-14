import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/app_constants.dart';

class DoubleTapDialog extends StatelessWidget {
  const DoubleTapDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    const textColor = Colors.white;
    final subTextColor = Colors.white.withValues(alpha: 0.8);

    return AlertDialog(
      backgroundColor: primaryColor,
      contentPadding: EdgeInsets.fromLTRB(20.w, 15.h, 20.w, 10.h),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Column(
        children: [
          Icon(Icons.tips_and_updates_outlined, color: Colors.white.withValues(alpha: 0.9), size: 30),
          SizedBox(height: 10.h),
          const Text(
            'تلميحات التصفح',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppConsts.cairo,
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.white,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHintRow(
              Icons.fullscreen_rounded,
              'ضغطتين',
              'تبديل وضع العرض (إظهار/إخفاء العناوين وأرقام الصفحات)',
              textColor,
              subTextColor,
            ),
            SizedBox(height: 15.h),
            _buildHintRow(
              Icons.zoom_in_rounded,
              'تكبير الصفحة',
              'استخدم أصبعين (القرص) لتكبير وتصغير الصفحة يدوياً',
              textColor,
              subTextColor,
            ),
            SizedBox(height: 15.h),
            _buildHintRow(
              Icons.touch_app_outlined,
              'ضغطة مطولة',
              'التفسير والمشاركة ومشغل الآيات لكل آية',
              textColor,
              subTextColor,
            ),
            SizedBox(height: 15.h),
            _buildHintRow(
              Icons.touch_app,
              'ضغطة واحدة',
              'إظهار قائمة الخيارات (المحفوظات، الألوان، البحث، الأوتو سكرول)',
              textColor,
              subTextColor,
            ),
            SizedBox(height: 15.h),
            _buildHintRow(
              Icons.palette_outlined,
              'تغيير المظهر (⚙️)',
              'يمكنك تغيير لون الورق، الهوامش، ووضع القراءة الليلي من قائمة الألوان',
              textColor,
              subTextColor,
            ),
          ],
        ),
      ),
      actions: [
        Center(
          child: TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 8.h),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'فهمت ذلك',
              style: TextStyle(
                color: Colors.white,
                fontFamily: AppConsts.cairo,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHintRow(
    IconData icon,
    String title,
    String desc,
    Color textColor,
    Color subTextColor,
  ) {
    return Row(
      textDirection: TextDirection.rtl,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: AppConsts.cairo,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: textColor,
                ),
                textDirection: TextDirection.rtl,
              ),
              Text(
                desc,
                style: TextStyle(
                  fontFamily: AppConsts.cairo,
                  fontSize: 12,
                  color: subTextColor,
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
