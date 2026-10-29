import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/core/helpers/mushaf_format_repository.dart';
import 'package:ibad_al_rahmann/features/quran/ui/widgets/menus/tajweed_color_legend.dart';

class MushafFormatPicker extends StatefulWidget {
  final MushafFormatRepository? repository;

  const MushafFormatPicker({super.key, this.repository});

  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const MushafFormatPicker(),
    );
  }

  @override
  State<MushafFormatPicker> createState() => _MushafFormatPickerState();
}

class _MushafFormatPickerState extends State<MushafFormatPicker> {
  static const _supportedFormatIds = <String>{
    'qpc_v1_builtin',
    'qpc_v2_1421',
    'qpc_v4_tajweed_1441',
    'digital_khatt_v2',
  };

  late final MushafFormatRepository _repository;
  String? _workingId;
  String? _error;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? MushafFormatRepository.instance;
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await _repository.refreshCatalog();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _choose(MushafFormat format, {bool download = false}) async {
    if (_workingId != null) return;
    setState(() {
      _workingId = format.id;
      _error = null;
    });
    try {
      if (download) await _repository.install(format.id);
      // Closing the picker does not silently activate a finished download.
      if (!mounted) return;
      await _repository.select(format.id);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      Navigator.of(context).pop();
      messenger?.showSnackBar(
        SnackBar(content: Text('تم تفعيل ${format.displayName}')),
      );
    } catch (error) {
      if (mounted && error is! MushafDownloadCancelledException) {
        setState(
          () => _error = download
              ? 'تعذر تنزيل هذا التنسيق أو التحقق من ملفاته.'
              : 'تعذر تفعيل التنسيق المحدد.',
        );
      }
    } finally {
      if (mounted) setState(() => _workingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AnimatedBuilder(
        animation: _repository,
        builder: (context, _) {
          final formats = _repository.formats;
          final visibleFormats = formats
              .where(
                (format) =>
                    _supportedFormatIds.contains(format.id) &&
                    format.compatible,
              )
              .toList();
          final hasAdditionalFormats = visibleFormats.any(
            (format) => !format.isBuiltin,
          );
          final hasTajweedFormat = visibleFormats.any(
            (format) => format.hasTajweed,
          );
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.dividerColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_stories_outlined),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'تنسيقات المصحف',
                            style: theme.textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          tooltip: 'تحديث القائمة',
                          onPressed: _refreshing ? null : _refresh,
                          icon: const Icon(Icons.refresh),
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'مصحف المدينة (1405هـ) موجود في التطبيق. اضغط على بطاقة أي تنسيق لمعرفة وصفه والفرق قبل التنزيل أو التفعيل. يستمر التنزيل في الخلفية، ويمكن متابعة تفاصيله من الإشعار.',
                    ),
                  ),
                  if (hasTajweedFormat)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        onPressed: () =>
                            unawaited(TajweedColorLegend.show(context)),
                        icon: const Icon(Icons.colorize_outlined),
                        label: const Text('دليل ألوان التجويد'),
                      ),
                    ),
                  if (_refreshing) const LinearProgressIndicator(),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                      child: Text(
                        _error!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(12, 14, 12, 20),
                      itemCount:
                          visibleFormats.length +
                          (!hasAdditionalFormats && !_refreshing ? 1 : 0),
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        if (index == visibleFormats.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'تعذّر تحميل التنسيقات الإضافية الآن. حدّث القائمة عند الاتصال بالإنترنت.',
                              textAlign: TextAlign.center,
                            ),
                          );
                        }
                        return _buildFormatTile(visibleFormats[index]);
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showFormatDetails(MushafFormat format) async {
    final action = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final isCurrent = _repository.current.id == format.id;
        final downloading = _repository.isDownloading(format.id);
        final installed = _repository.isInstalled(format.id);
        final canSelect =
            !isCurrent &&
            !downloading &&
            _workingId == null &&
            format.compatible;
        final size = format.sizeBytes;
        final buttonLabel = isCurrent
            ? 'مفعّل الآن'
            : downloading
            ? 'جارٍ التنزيل'
            : _workingId != null
            ? 'انتظر حتى تنتهي العملية الحالية'
            : installed
            ? 'تفعيل هذا التنسيق'
            : 'تنزيل هذا التنسيق';
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: SingleChildScrollView(
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
                    const SizedBox(height: 18),
                    Text(format.displayName, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 10),
                    Text(_formatDescription(format)),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text('${format.pageCount} صفحة')),
                        Chip(label: Text('${format.lineCount} سطرًا للصفحة')),
                        if (format.hasTajweed)
                          const Chip(label: Text('ألوان لأحكام التجويد')),
                        if (format.isUnicodeFont)
                          const Chip(label: Text('خط موحّد للصفحات')),
                        if (size != null && size > 0)
                          Chip(
                            label: Text(
                              '${(size / (1024 * 1024)).ceil()} م.ب للتنزيل',
                            ),
                          ),
                      ],
                    ),
                    if (!format.isBuiltin &&
                        !format.paginationMatchesBuiltin) ...[
                      const SizedBox(height: 8),
                      Text(
                        'قد يختلف توزيع الآيات على الصفحات عن نسخة 1405هـ؛ '
                        'ويعتمد الانتقال على فهرس هذا التنسيق.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () =>
                                Navigator.of(sheetContext).pop(false),
                            child: const Text('إغلاق'),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: canSelect
                                ? () => Navigator.of(sheetContext).pop(true)
                                : null,
                            icon: Icon(
                              installed
                                  ? Icons.check_circle_outline
                                  : Icons.download_outlined,
                            ),
                            label: Text(buttonLabel),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    if (action == true && mounted) {
      await _choose(format, download: !_repository.isInstalled(format.id));
    }
  }

  String _formatDescription(MushafFormat format) {
    final description = format.description.trim();
    if (description.isNotEmpty) return description;
    return switch (format.id) {
      'qpc_v1_builtin' =>
        'المصحف الأصلي المضمّن في التطبيق — إصدار 1405هـ، ولا يحتاج إلى تنزيل.',
      'qpc_v2_1421' =>
        'طبعة مصحف المدينة لعام 1421هـ، بصفحات من 15 سطرًا. يختلف توزيع '
            'بعض الآيات عن نسخة 1405هـ المضمّنة في التطبيق.',
      'qpc_v4_tajweed_1441' =>
        'طبعة 1441هـ مع تلوين بصري لأحكام التجويد. يختلف توزيع بعض الآيات '
            'عن نسخة 1405هـ المضمّنة في التطبيق.',
      'digital_khatt_v2' =>
        'يعرض صفحات المصحف باستخدام خط رقمي موحّد بدل خط منفصل لكل صفحة؛ '
            'يتغيّر بذلك شكل الحروف المعروضة.',
      _ => 'تنسيق إضافي للمصحف متوافق مع عرض التطبيق.',
    };
  }

  Widget _buildFormatTile(MushafFormat format) {
    final installed = _repository.isInstalled(format.id);
    final isCurrent = _repository.current.id == format.id;
    final downloading = _repository.isDownloading(format.id);
    final downloadDetails = _repository.downloadDetails(format.id);
    Widget action;
    if (isCurrent) {
      action = const Chip(
        avatar: Icon(Icons.check_circle_outline, size: 18),
        label: Text('الحالي'),
      );
    } else if (downloading) {
      action = IconButton(
        tooltip: 'إلغاء التنزيل',
        onPressed: () => unawaited(_repository.cancelDownload(format.id)),
        icon: const Icon(Icons.close),
      );
    } else if (_workingId == format.id) {
      action = const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (!format.compatible) {
      action = const Tooltip(
        message: 'غير متوافق مع المصحف الحالي',
        child: Icon(Icons.block_outlined),
      );
    } else {
      action = TextButton(
        onPressed: _workingId == null
            ? () => _choose(format, download: !installed)
            : null,
        child: Text(installed ? 'تفعيل' : 'تنزيل'),
      );
    }
    final size = format.sizeBytes;
    final detail = [
      _formatDescription(format),
      if (!format.compatible) 'غير متوافق مع صفحات التطبيق الحالية',
      '${format.pageCount} صفحة · ${format.lineCount} سطرًا',
      if (format.hasTajweed) 'تلوين أحكام التجويد',
      if (!format.isBuiltin && !format.paginationMatchesBuiltin)
        'توزيع صفحات مختلف عن إصدار 1405هـ',
      if (format.isUnicodeFont) 'خط موحّد للصفحات',
      if (size != null && size > 0) '${(size / (1024 * 1024)).ceil()} م.ب',
    ].where((value) => value.isNotEmpty).join(' · ');
    return ListTile(
      leading: Icon(
        format.hasTajweed ? Icons.colorize_outlined : Icons.menu_book_outlined,
      ),
      title: Text(format.displayName, softWrap: true),
      onTap: () => unawaited(_showFormatDetails(format)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(detail, softWrap: true),
          if (downloading && downloadDetails != null) ...[
            const SizedBox(height: 8),
            _buildDownloadDetails(downloadDetails),
          ],
          if (downloading && downloadDetails == null) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
            const SizedBox(height: 4),
            const Text('جارٍ تجهيز التنزيل…'),
          ],
        ],
      ),
      trailing: action,
    );
  }

  Widget _buildDownloadDetails(MushafDownloadDetails details) {
    final theme = Theme.of(context);
    final progress = details.progress?.clamp(0.0, 1.0).toDouble();
    final phaseLabel = switch (details.phase) {
      MushafDownloadPhase.queued => 'بانتظار بدء التنزيل',
      MushafDownloadPhase.downloading => 'جارٍ التنزيل',
      MushafDownloadPhase.verifying => 'جارٍ التحقق من الملفات وتثبيتها',
    };
    final total = details.totalBytes;
    final receivedLabel = total == null
        ? 'تم تنزيل ${_formatMegabytes(details.downloadedBytes)}'
        : 'تم تنزيل ${_formatMegabytes(details.downloadedBytes)} من ${_formatMegabytes(total)}';
    final speed = details.speedBytesPerSecond;
    final remaining = details.timeRemaining;
    final extraDetails = <String>[
      if (speed != null && speed > 0)
        '${(speed / (1024 * 1024)).toStringAsFixed(1)} م.ب/ث',
      if (remaining != null && remaining.inSeconds > 0)
        'متبقٍ نحو ${_formatRemainingTime(remaining)}',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(value: progress),
        const SizedBox(height: 5),
        Text(
          [
            phaseLabel,
            receivedLabel,
            if (progress != null) '${(progress * 100).round()}٪',
            ...extraDetails,
          ].join(' · '),
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  String _formatMegabytes(int bytes) =>
      '${(bytes / (1024 * 1024)).toStringAsFixed(1)} م.ب';

  String _formatRemainingTime(Duration remaining) {
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds.remainder(60);
    return minutes > 0 ? '$minutes د و$seconds ث' : '$seconds ث';
  }
}
