import 'package:flutter/material.dart';
import '../widgets/core/selected_mushaf_page_widget.dart';

class MobileFullPageRichText extends StatelessWidget {
  const MobileFullPageRichText({
    super.key,
    required this.pageNumber,
    this.paperColorOverride,
  });

  final int pageNumber;
  final Color? paperColorOverride;

  @override
  Widget build(BuildContext context) {
    // استخدمنا نفس الويدجت الجبارة بتاعة مصحف الورد اللي شغالة بدون أي أخطاء
    return SelectedMushafPageWidget(
      pageNumber: pageNumber,
      isZoomEnabled: true, // تفعيل الزووم زي الورد
      showHeader: true, // عرض اسم السورة والجزء فوق
      showPageNumber: true, // عرض برواز رقم الصفحة تحت
      paperColorOverride: paperColorOverride,
    );
  }
}
