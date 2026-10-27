import 'package:flutter/material.dart';

class MushafSettingsPanel extends StatelessWidget {
  final ValueChanged<String> onSelectionChanged;

  const MushafSettingsPanel({super.key, required this.onSelectionChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.primaryColor;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('إعدادات المصحف', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            _SettingTile(
              icon: Icons.color_lens_outlined,
              title: 'الألوان',
              subtitle: 'لون الورق والهوامش ووضع القراءة',
              accent: accent,
              onTap: () => onSelectionChanged('colors'),
            ),
            const SizedBox(height: 8),
            _SettingTile(
              icon: Icons.auto_stories_outlined,
              title: 'تنسيقات المصحف',
              subtitle: 'تنزيل تنسيق مدعوم أو تفعيله',
              accent: accent,
              onTap: () => onSelectionChanged('format'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(icon, color: accent),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Icon(Icons.chevron_left, color: accent),
        onTap: onTap,
      ),
    );
  }
}
