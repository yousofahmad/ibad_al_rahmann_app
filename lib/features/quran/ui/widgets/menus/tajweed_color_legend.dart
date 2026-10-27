import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class TajweedColorLegend {
  const TajweedColorLegend._();

  static const _sourceUrl =
      'https://support.tarteel.ai/en/articles/14936922-understanding-tajweed-colors-in-the-tarteel-mushaf';

  static const _rules = <_TajweedRule>[
    _TajweedRule(
      color: Color(0xFFB50000),
      name: 'المد اللازم',
      detail: 'ست حركات',
    ),
    _TajweedRule(
      color: Color(0xFFF40000),
      name: 'المد الواجب المتصل',
      detail: 'أربع أو خمس حركات',
    ),
    _TajweedRule(
      color: Color(0xFFFF7B00),
      name: 'المد العارض للسكون',
      detail: 'حركتان أو أربع أو ست عند الوقف',
    ),
    _TajweedRule(
      color: Color(0xFFCE9E00),
      name: 'المد الطبيعي',
      detail: 'حركتان',
    ),
    _TajweedRule(
      color: Color(0xFF09B000),
      name: 'الغُنّة',
      detail: 'غُنّة النون والميم، بمقدار حركتين',
    ),
    _TajweedRule(
      color: Color(0xFF2FADFF),
      name: 'القلقلة',
      detail: 'حروف «قطب جد» الساكنة',
    ),
    _TajweedRule(
      color: Color(0xFF3F48E6),
      name: 'التفخيم',
      detail: 'الحروف المفخمة، ومنها الراء في مواضعها',
    ),
    _TajweedRule(
      color: Color(0xFFA5A5A5),
      name: 'حروف لا تُنطق',
      detail: 'الحروف الصامتة في الرسم',
    ),
  ];

  static Future<void> show(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          scrollable: true,
          title: const Text('دليل ألوان التجويد'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('كل لون يميّز حكمًا محددًا في خطّ التجويد الملوّن:'),
              const SizedBox(height: 8),
              for (final rule in _rules)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.circle, color: rule.color, size: 22),
                  title: Text(rule.name),
                  subtitle: Text(rule.detail),
                ),
              const SizedBox(height: 8),
              const Text(
                'ليس كل حكم تجويد ملوّنًا في هذا النظام؛ فالإظهار والإدغام والإخفاء لا تُعرض بألوان خاصة هنا.',
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () => launchUrl(
                Uri.parse(_sourceUrl),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('المصدر: دليل Tarteel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TajweedRule {
  const _TajweedRule({
    required this.color,
    required this.name,
    required this.detail,
  });

  final Color color;
  final String name;
  final String detail;
}
