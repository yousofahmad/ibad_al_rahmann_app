import 'package:flutter/material.dart';

import '../services/egyptian_hijri_calendar.dart';
import '../services/egyptian_hijri_sync.dart';

class EgyptianHijriSyncStatus extends StatefulWidget {
  const EgyptianHijriSyncStatus({super.key});

  @override
  State<EgyptianHijriSyncStatus> createState() =>
      _EgyptianHijriSyncStatusState();
}

class _EgyptianHijriSyncStatusState extends State<EgyptianHijriSyncStatus> {
  static bool _confirmationDialogOpen = false;

  bool _refreshing = false;
  bool _dialogScheduled = false;

  EgyptianHijriCalendar get _calendar => EgyptianHijriCalendar.instance;
  EgyptianHijriSync get _sync => EgyptianHijriSync.instance;

  @override
  void initState() {
    super.initState();
    _calendar.addListener(_onCalendarChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scheduleAutomaticConfirmation();
    });
  }

  @override
  void dispose() {
    _calendar.removeListener(_onCalendarChanged);
    super.dispose();
  }

  void _onCalendarChanged() {
    if (!mounted) return;
    setState(() {});
    _scheduleAutomaticConfirmation();
  }

  void _scheduleAutomaticConfirmation() {
    if (_dialogScheduled || !mounted) return;
    final pending = _calendar.pendingConfirmation;
    if (!_calendar.shouldPromptConfirmation || pending == null) return;
    _dialogScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dialogScheduled = false;
      if (!mounted || !_calendar.shouldPromptConfirmation) return;
      if (_calendar.pendingConfirmation == null) return;
      if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
      _showConfirmationDialog();
    });
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await _sync.refresh(force: true);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _showConfirmationDialog() async {
    if (!mounted || _confirmationDialogOpen) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    final pending = _calendar.pendingConfirmation;
    if (pending == null) return;

    _confirmationDialogOpen = true;
    try {
      final selected = await showDialog<_HijriChoice>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) =>
            _buildConfirmationDialog(dialogContext, pending),
      );
      if (!mounted || selected == null) return;
      if (selected.adjustment == null) {
        try {
          await _sync.deferConfirmation();
        } catch (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('تعذر حفظ تأجيل التأكيد: $error')),
            );
          }
        }
        return;
      }
      try {
        await _sync.confirmDate(
          civilDate: pending.civilDate,
          displayedDate: pending.displayedDate,
          adjustment: selected.adjustment!,
        );
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تعذر حفظ تأكيد التاريخ: $error')),
          );
        }
      }
    } finally {
      _confirmationDialogOpen = false;
    }
  }

  AlertDialog _buildConfirmationDialog(
    BuildContext dialogContext,
    PendingHijriConfirmation pending,
  ) {
    final calendar = _calendar;
    final displayed = pending.displayedDate;
    _HijriChoice choice(String prefix, int adjustment) {
      final date = calendar.choiceForAdjustment(
        pending.civilDate,
        displayed,
        adjustment,
      );
      return _HijriChoice(
        label: date == null ? prefix : '$prefix ${_arabicDate(date)}',
        adjustment: adjustment,
        date: date,
      );
    }

    final choices = <_HijriChoice>[
      choice('صحيح —', 0),
      choice('أقل بيوم —', -1),
      choice('أكثر بيوم —', 1),
    ];

    final boundaryText = displayed.hDay >= 29
        ? 'سنعيد التحقق عند حد الشهر.'
        : 'سنستخدم تأكيدك حتى يوم ٢٩ ثم نعيد التحقق.';
    return AlertDialog(
      title: const Text('تأكيد التاريخ الهجري'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'تأكيد تاريخ اليوم في مصر: ${_arabicDigits('${pending.civilDate.day}/${pending.civilDate.month}/${pending.civilDate.year}')}',
            ),
            const SizedBox(height: 8),
            const Text(
              'قد ينتج الاختلاف عن تأخر تحديث المصدر، وليس دليلًا أن المساحة مخطئة.',
            ),
            const SizedBox(height: 12),
            if (pending.surveyDate != null)
              Text('قيمة المساحة: ${_arabicDate(pending.surveyDate!)}'),
            if (pending.darDate != null)
              Text('قيمة دار الإفتاء: ${_arabicDate(pending.darDate!)}'),
            if (pending.surveyDate == null && pending.darDate == null)
              Text('المصدر المتاح: ${_arabicDate(displayed)}'),
            if (pending.reason.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('سبب المراجعة: ${_reasonLabel(pending.reason)}'),
            ],
            const SizedBox(height: 12),
            Text('التاريخ المعروض ${_arabicDate(displayed)}، تؤكده أم تعدله؟'),
            const SizedBox(height: 8),
            for (final choice in choices)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: OutlinedButton(
                  onPressed: choice.date == null
                      ? null
                      : () => Navigator.of(dialogContext).pop(choice),
                  child: Text(choice.label),
                ),
              ),
            Text(boundaryText),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(
            const _HijriChoice(label: 'لاحقًا', adjustment: null, date: null),
          ),
          child: const Text('لاحقًا'),
        ),
      ],
    );
  }

  String _arabicDate(EgyptianHijriDate date) => _arabicDigits(date.format);

  String _reasonLabel(String reason) => switch (reason) {
    'manual_recheck' => 'بلغ تأكيدك السابق حد يوم ٢٩ أو انتهت مدته.',
    'sources_disagree' => 'المصدران يعرضان تاريخين مختلفين.',
    'survey_unavailable' => 'جدول المساحة غير متاح لهذا اليوم.',
    'verification_unavailable' => 'تعذر حسم اختلاف سابق من المصادر الآن.',
    _ => 'نحتاج مراجعة تاريخ اليوم.',
  };

  String _arabicDigits(String value) => value.replaceAllMapped(
    RegExp(r'[0-9]'),
    (match) => '٠١٢٣٤٥٦٧٨٩'[int.parse(match.group(0)!)],
  );

  @override
  Widget build(BuildContext context) {
    final calendar = _calendar;
    final pending = calendar.pendingConfirmation;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              calendar.lastError != null
                  ? '${calendar.verificationStatus ?? 'نحتفظ بآخر بيانات متاحة.'} آخر محاولة للمصادر لم تكتمل.'
                  : (calendar.verificationStatus ??
                        'التاريخ موحد لكل مصر؛ جارٍ التحقق من المصدر الرسمي.'),
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
          if (pending != null)
            TextButton(
              onPressed: _showConfirmationDialog,
              child: const Text('تأكيد التاريخ'),
            ),
          if (_refreshing)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              onPressed: _refresh,
              tooltip: 'التحقق من تاريخ دار الإفتاء وجدول المساحة',
              icon: const Icon(Icons.sync, size: 20),
            ),
        ],
      ),
    );
  }
}

class _HijriChoice {
  final String label;
  final int? adjustment;
  final EgyptianHijriDate? date;

  const _HijriChoice({
    required this.label,
    required this.adjustment,
    required this.date,
  });
}
