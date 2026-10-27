import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:gal/gal.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:ibad_al_rahmann/features/quran_audio/data/surah_list.dart';
import 'package:ibad_al_rahmann/features/quran_reciters/data/models/reciter_model.dart';
import 'package:ibad_al_rahmann/features/quran_video/models/quran_video_options.dart';
import 'package:ibad_al_rahmann/features/quran_video/services/quran_video_background_preview_service.dart';
import 'package:ibad_al_rahmann/features/quran_video/services/quran_video_export_service.dart';
import 'package:ibad_al_rahmann/features/quran_video/ui/quran_video_caption_preview.dart';
import 'package:path/path.dart' as p;
import 'package:quran/quran.dart' as quran;
import 'package:share_plus/share_plus.dart';

class QuranVideoCreatorScreen extends StatefulWidget {
  const QuranVideoCreatorScreen({
    super.key,
    required this.initialReciter,
    this.initialSurah,
  });

  final ReciterAudioModel initialReciter;
  final int? initialSurah;

  @override
  State<QuranVideoCreatorScreen> createState() =>
      _QuranVideoCreatorScreenState();
}

class _QuranVideoCreatorScreenState extends State<QuranVideoCreatorScreen> {
  final QuranVideoExportService _exportService = QuranVideoExportService();
  final QuranVideoBackgroundPreviewService _backgroundPreviewService =
      const QuranVideoBackgroundPreviewService();
  final TextEditingController _fromVerseController = TextEditingController(
    text: '1',
  );
  final TextEditingController _toVerseController = TextEditingController(
    text: '7',
  );

  late List<ReciterAudioModel> _reciters;
  late ReciterAudioModel _reciter;
  late int _surahNumber;
  QuranVideoBackgroundType _backgroundType = QuranVideoBackgroundType.image;
  QuranVideoExportOptions _options = const QuranVideoExportOptions();
  String? _backgroundPath;
  String? _videoPreviewPath;
  int _backgroundPreviewRequest = 0;
  bool _isPreparingBackgroundPreview = false;
  QuranVideoExportProgress? _progress;
  QuranVideoExportResult? _result;
  bool _isExporting = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _reciters = List<ReciterAudioModel>.from(
      ReciterAudioHelper.availableReciters,
    );
    if (!_reciters.any(
      (candidate) => candidate.id == widget.initialReciter.id,
    )) {
      _reciters.add(widget.initialReciter);
    }
    _reciter = _reciters.firstWhere(
      (candidate) => candidate.id == widget.initialReciter.id,
      orElse: () => widget.initialReciter,
    );
    _surahNumber = (widget.initialSurah ?? 1).clamp(1, 114);
    _toVerseController.text = quran
        .getVerseCount(_surahNumber)
        .clamp(1, 7)
        .toString();
  }

  @override
  void dispose() {
    _backgroundPreviewRequest++;
    if (_isExporting) unawaited(_exportService.cancel());
    _fromVerseController.dispose();
    _toVerseController.dispose();
    super.dispose();
  }

  int get _fromVerse => int.tryParse(_fromVerseController.text.trim()) ?? 0;
  int get _toVerse => int.tryParse(_toVerseController.text.trim()) ?? 0;
  int get _verseCount => quran.getVerseCount(_surahNumber);
  bool get _hasWordTiming => _reciter.supportsWordByWord;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return PopScope<Object?>(
      canPop: !_isExporting,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('منشئ فيديو القرآن'),
          centerTitle: true,
          leading: IconButton(
            onPressed: _isExporting ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                children: [
                  _buildPreview(theme),
                  const SizedBox(height: 14),
                  _sectionCard(
                    theme,
                    icon: Icons.wallpaper_rounded,
                    title: 'الخلفية',
                    child: _buildBackgroundControls(theme),
                  ),
                  _sectionCard(
                    theme,
                    icon: Icons.menu_book_rounded,
                    title: 'التلاوة والآيات',
                    child: _buildQuranControls(theme),
                  ),
                  _sectionCard(
                    theme,
                    icon: Icons.text_fields_rounded,
                    title: 'شكل النص والتظليل',
                    child: _buildTextControls(theme),
                  ),
                  _sectionCard(
                    theme,
                    icon: Icons.high_quality_rounded,
                    title: 'إعدادات الفيديو',
                    child: _buildOutputControls(theme),
                  ),
                  if (_result != null) _buildResultCard(theme),
                  const SizedBox(height: 6),
                ],
              ),
            ),
            _buildExportFooter(theme, primary),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary, size: 21),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontFamily: AppConsts.expoArabic,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }

  bool get _hasPreviewBackground =>
      _backgroundPath != null &&
      (_backgroundType != QuranVideoBackgroundType.video ||
          _videoPreviewPath != null);

  bool get _canExpandPreview =>
      _hasPreviewBackground &&
      !_isPreparingBackgroundPreview &&
      _safePreviewVerse() != null;

  String get _previewDescription {
    if (_isPreparingBackgroundPreview) {
      return 'جارٍ تجهيز معاينة أول إطار من مقطع الفيديو…';
    }
    if (_backgroundPath == null) {
      return 'اختر صورة أو مقطع فيديو لعرض الخلفية الفعلية قبل التصدير.';
    }
    if (!_hasPreviewBackground) return 'تعذر تجهيز معاينة الخلفية.';
    if (_safePreviewVerse() == null) {
      return 'راجع نطاق الآيات لعرض معاينة صحيحة.';
    }
    final backgroundNote = _backgroundType == QuranVideoBackgroundType.video
        ? 'إطار الفيديو الأول'
        : 'الصورة المختارة';
    return 'معاينة الآية $_fromVerse من النطاق المحدد مع $backgroundNote.';
  }

  Widget _buildPreview(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPreviewFrame(theme),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                _previewDescription,
                style: theme.textTheme.bodySmall,
              ),
            ),
            TextButton.icon(
              onPressed: _canExpandPreview ? _showExpandedPreview : null,
              icon: const Icon(Icons.fullscreen_rounded, size: 19),
              label: const Text('تكبير المعاينة'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPreviewFrame(ThemeData theme) {
    final previewVerse = _safePreviewVerse();
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: AspectRatio(
        aspectRatio: _options.aspectRatio.ratio,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final previewShortSide = math.min(
              constraints.maxWidth,
              constraints.maxHeight,
            );
            final previewFont = _options.fontSize * previewShortSide / 1080;
            final alignmentY = (_options.position * 2 - 1).clamp(-0.9, 0.9);
            return Stack(
              fit: StackFit.expand,
              children: [
                _buildPreviewBackground(theme),
                if (_hasPreviewBackground &&
                    !_isPreparingBackgroundPreview &&
                    previewVerse != null)
                  Align(
                    alignment: Alignment(0, alignmentY),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: _options.showTextPanel
                            ? BoxDecoration(
                                color: Colors.black.withValues(
                                  alpha: _options.panelOpacity,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              )
                            : null,
                        child: QuranVideoCaptionPreview(
                          verse: previewVerse,
                          options: _options,
                          fontSize: previewFont,
                        ),
                      ),
                    ),
                  )
                else if (_hasPreviewBackground &&
                    !_isPreparingBackgroundPreview)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'أدخل نطاق آيات صحيحًا لعرض النص الذي سيُصدَّر.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                if (_isPreparingBackgroundPreview)
                  const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPreviewBackground(ThemeData theme) {
    if (_backgroundPath != null &&
        _backgroundType == QuranVideoBackgroundType.image) {
      return Image.file(
        File(_backgroundPath!),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) =>
            _emptyPreviewBackground('تعذر تحميل الصورة المختارة.', theme),
      );
    }
    if (_videoPreviewPath != null &&
        _backgroundType == QuranVideoBackgroundType.video) {
      return Image.file(
        File(_videoPreviewPath!),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) =>
            _emptyPreviewBackground('تعذر تحميل إطار الفيديو.', theme),
      );
    }
    return _emptyPreviewBackground(
      _isPreparingBackgroundPreview
          ? 'جارٍ تجهيز معاينة الفيديو…'
          : 'اختر خلفية لعرض المعاينة الفعلية.',
      theme,
    );
  }

  Widget _emptyPreviewBackground(String message, ThemeData theme) {
    return ColoredBox(
      color: const Color(0xFF111111),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
        ),
      ),
    );
  }

  Future<void> _showExpandedPreview() async {
    if (!_canExpandPreview) return;
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final previewWidth = math.min(
      size.width - 48,
      size.height * 0.65 * _options.aspectRatio.ratio,
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'معاينة قبل التصدير',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'إغلاق المعاينة',
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(width: previewWidth, child: _buildPreviewFrame(theme)),
              const SizedBox(height: 8),
              Text(
                'الآية $_fromVerse من سورة ${quranSurahs[_surahNumber - 1]} · النص والألوان والموضع كما ستظهر في الفيديو.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _safePreviewVerse() {
    if (_fromVerse < 1 ||
        _fromVerse > _verseCount ||
        _toVerse < _fromVerse ||
        _toVerse > _verseCount) {
      return null;
    }
    try {
      return quran.getVerse(_surahNumber, _fromVerse);
    } catch (_) {
      return null;
    }
  }

  Widget _buildBackgroundControls(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<QuranVideoBackgroundType>(
          segments: const [
            ButtonSegment(
              value: QuranVideoBackgroundType.image,
              icon: Icon(Icons.image_outlined),
              label: Text('صورة'),
            ),
            ButtonSegment(
              value: QuranVideoBackgroundType.video,
              icon: Icon(Icons.movie_outlined),
              label: Text('فيديو'),
            ),
          ],
          selected: {_backgroundType},
          onSelectionChanged: _isExporting
              ? null
              : (selection) {
                  _backgroundPreviewRequest++;
                  setState(() {
                    _backgroundType = selection.first;
                    _backgroundPath = null;
                    _videoPreviewPath = null;
                    _isPreparingBackgroundPreview = false;
                    _result = null;
                  });
                },
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _isExporting ? null : _pickBackground,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: Text(
            _backgroundPath == null
                ? (_backgroundType == QuranVideoBackgroundType.image
                      ? 'اختيار صورة'
                      : 'اختيار مقطع فيديو')
                : 'تغيير الخلفية',
          ),
        ),
        if (_backgroundPath != null) ...[
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(
                child: Text(
                  p.basename(_backgroundPath!),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                  textDirection: TextDirection.ltr,
                ),
              ),
              IconButton(
                tooltip: 'إزالة الخلفية',
                visualDensity: VisualDensity.compact,
                onPressed: _isExporting
                    ? null
                    : () {
                        _backgroundPreviewRequest++;
                        setState(() {
                          _backgroundPath = null;
                          _videoPreviewPath = null;
                          _isPreparingBackgroundPreview = false;
                          _result = null;
                        });
                      },
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ],
        if (_backgroundType == QuranVideoBackgroundType.video)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'سيُستبدل صوت المقطع بصوت التلاوة، ولن يُدمج الصوتان.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildQuranControls(ThemeData theme) {
    final modes = <QuranVideoDisplayMode>[
      QuranVideoDisplayMode.ayahByAyah,
      if (_hasWordTiming) ...[
        QuranVideoDisplayMode.wordHighlight,
        QuranVideoDisplayMode.wordReveal,
      ],
    ];
    if (!modes.contains(_options.displayMode)) {
      _options = _options.copyWith(
        displayMode: QuranVideoDisplayMode.ayahByAyah,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<ReciterAudioModel>(
          initialValue: _reciter,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'القارئ',
            border: OutlineInputBorder(),
          ),
          items: _reciters
              .map(
                (reciter) => DropdownMenuItem(
                  value: reciter,
                  child: Text(
                    '${reciter.name} — ${reciter.style}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: _isExporting
              ? null
              : (value) {
                  if (value == null) return;
                  setState(() {
                    _reciter = value;
                    _result = null;
                    if (!value.supportsWordByWord) {
                      _options = _options.copyWith(
                        displayMode: QuranVideoDisplayMode.ayahByAyah,
                      );
                    }
                  });
                },
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<int>(
          initialValue: _surahNumber,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'السورة',
            border: OutlineInputBorder(),
          ),
          items: List<DropdownMenuItem<int>>.generate(
            quranSurahs.length,
            (index) => DropdownMenuItem(
              value: index + 1,
              child: Text('سورة ${quranSurahs[index]}'),
            ),
          ),
          onChanged: _isExporting
              ? null
              : (value) {
                  if (value == null) return;
                  setState(() {
                    _surahNumber = value;
                    _fromVerseController.text = '1';
                    _toVerseController.text = quran
                        .getVerseCount(value)
                        .clamp(1, 7)
                        .toString();
                    _result = null;
                  });
                },
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _fromVerseController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                enabled: !_isExporting,
                decoration: const InputDecoration(
                  labelText: 'من الآية',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() => _result = null),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _toVerseController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                enabled: !_isExporting,
                decoration: const InputDecoration(
                  labelText: 'إلى الآية',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() => _result = null),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<QuranVideoDisplayMode>(
          initialValue: _options.displayMode,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'طريقة ظهور الآيات',
            border: OutlineInputBorder(),
          ),
          items: modes
              .map(
                (mode) => DropdownMenuItem(
                  value: mode,
                  child: Text(_displayModeLabel(mode)),
                ),
              )
              .toList(),
          onChanged: _isExporting
              ? null
              : (value) {
                  if (value != null) {
                    setState(() {
                      _options = _options.copyWith(displayMode: value);
                      _result = null;
                    });
                  }
                },
        ),
        if (!_hasWordTiming)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'يتوفر التظليل كلمة بكلمة فقط للقراء الذين لديهم بيانات توقيت الكلمات؛ هذا القارئ يدعم العرض آية بآية.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.secondary,
              ),
            ),
          ),
      ],
    );
  }

  String _displayModeLabel(QuranVideoDisplayMode mode) => switch (mode) {
    QuranVideoDisplayMode.ayahByAyah => 'إظهار آية كاملة في كل مرة',
    QuranVideoDisplayMode.wordHighlight =>
      'الآية كاملة مع تظليل الكلمة المقروءة',
    QuranVideoDisplayMode.wordReveal => 'إظهار كلمة واحدة بالتتابع',
  };

  Widget _buildTextControls(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'حجم الخط: ${_options.fontSize}',
          style: theme.textTheme.bodyMedium,
        ),
        Slider(
          min: 28,
          max: 76,
          divisions: 24,
          value: _options.fontSize.toDouble().clamp(28, 76),
          label: _options.fontSize.toString(),
          onChanged: _isExporting
              ? null
              : (value) => setState(() {
                  _options = _options.copyWith(fontSize: value.round());
                  _result = null;
                }),
        ),
        Text(
          'موضع النص: ${(100 * _options.position).round()}٪ من أعلى الإطار',
          style: theme.textTheme.bodyMedium,
        ),
        Slider(
          min: 0.22,
          max: 0.86,
          divisions: 32,
          value: _options.position.clamp(0.22, 0.86),
          onChanged: _isExporting
              ? null
              : (value) => setState(() {
                  _options = _options.copyWith(position: value);
                  _result = null;
                }),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _isExporting
                  ? null
                  : () => _chooseColor(
                      title: 'لون النص',
                      initialColor: _options.textColor,
                      onSelected: (color) =>
                          _options = _options.copyWith(textColor: color),
                    ),
              icon: _colorDot(_options.textColor),
              label: const Text('لون النص'),
            ),
            OutlinedButton.icon(
              onPressed: _isExporting
                  ? null
                  : () => _chooseColor(
                      title: 'لون التظليل',
                      initialColor: _options.highlightColor,
                      onSelected: (color) =>
                          _options = _options.copyWith(highlightColor: color),
                    ),
              icon: _colorDot(_options.highlightColor),
              label: const Text('لون التظليل'),
            ),
          ],
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('تظليل الآية أو الكلمة النشطة'),
          value: _options.showHighlight,
          onChanged: _isExporting
              ? null
              : (value) => setState(() {
                  _options = _options.copyWith(showHighlight: value);
                  _result = null;
                }),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('خلفية شبه شفافة أسفل النص'),
          value: _options.showTextPanel,
          onChanged: _isExporting
              ? null
              : (value) => setState(() {
                  _options = _options.copyWith(showTextPanel: value);
                  _result = null;
                }),
        ),
        if (_options.showTextPanel) ...[
          Text(
            'شفافية الخلفية: ${(100 * _options.panelOpacity).round()}٪',
            style: theme.textTheme.bodySmall,
          ),
          Slider(
            min: 0.15,
            max: 0.9,
            divisions: 15,
            value: _options.panelOpacity.clamp(0.15, 0.9),
            onChanged: _isExporting
                ? null
                : (value) => setState(() {
                    _options = _options.copyWith(panelOpacity: value);
                    _result = null;
                  }),
          ),
        ],
      ],
    );
  }

  Widget _colorDot(Color color) => Container(
    width: 20,
    height: 20,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.black26),
    ),
  );

  Future<void> _chooseColor({
    required String title,
    required Color initialColor,
    required ValueChanged<Color> onSelected,
  }) async {
    var selectedColor = initialColor;
    final color = await showDialog<Color>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: selectedColor,
            onColorChanged: (value) => selectedColor = value,
            enableAlpha: false,
            labelTypes: const [],
            pickerAreaHeightPercent: 0.72,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(selectedColor),
            child: const Text('اختيار'),
          ),
        ],
      ),
    );
    if (color == null || !mounted) return;
    setState(() {
      onSelected(color);
      _result = null;
    });
  }

  Widget _buildOutputControls(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<QuranVideoAspectRatio>(
          initialValue: _options.aspectRatio,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'أبعاد الفيديو',
            border: OutlineInputBorder(),
          ),
          items: QuranVideoAspectRatio.values
              .map(
                (ratio) =>
                    DropdownMenuItem(value: ratio, child: Text(ratio.label)),
              )
              .toList(),
          onChanged: _isExporting
              ? null
              : (value) {
                  if (value != null) {
                    setState(() {
                      _options = _options.copyWith(aspectRatio: value);
                      _result = null;
                    });
                  }
                },
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<QuranVideoResolution>(
          initialValue: _options.resolution,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'الدقة والضغط',
            border: OutlineInputBorder(),
          ),
          items: QuranVideoResolution.values
              .map(
                (resolution) => DropdownMenuItem(
                  value: resolution,
                  child: Text(resolution.label),
                ),
              )
              .toList(),
          onChanged: _isExporting
              ? null
              : (value) {
                  if (value != null) {
                    setState(() {
                      _options = _options.copyWith(resolution: value);
                      _result = null;
                    });
                  }
                },
        ),
        const SizedBox(height: 8),
        Text(
          'تصدير MP4 بترميز H.264 مُسرّع، صوت AAC للتلاوة فقط، وتحجيم يحافظ على إطار الخلفية. 1080p افتراضيًا بجودة متوازنة لتقليل الحجم.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildExportFooter(ThemeData theme, Color primary) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_progress != null && _isExporting) ...[
              LinearProgressIndicator(value: _progress!.fraction),
              const SizedBox(height: 7),
              Text(
                _progress!.message,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isExporting
                    ? _cancelExport
                    : _isPreparingBackgroundPreview
                    ? null
                    : _startExport,
                icon: _isPreparingBackgroundPreview
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _isExporting
                            ? Icons.cancel_outlined
                            : Icons.movie_creation_outlined,
                      ),
                label: Text(
                  _isExporting
                      ? 'إلغاء التصدير'
                      : _isPreparingBackgroundPreview
                      ? 'جارٍ تجهيز المعاينة…'
                      : 'إنشاء الفيديو',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _isExporting
                      ? theme.colorScheme.error
                      : primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(ThemeData theme) {
    final result = _result!;
    final sizeMb = result.fileSizeBytes / (1024 * 1024);
    return _sectionCard(
      theme,
      icon: Icons.check_circle_outline_rounded,
      title: 'الفيديو جاهز',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${_formatDuration(result.durationMs)} · ${sizeMb.toStringAsFixed(1)} MB · MP4',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : _saveToGallery,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_rounded),
                  label: const Text('حفظ في المعرض'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _shareVideo,
                  icon: const Icon(Icons.share_rounded),
                  label: const Text('مشاركة'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickBackground() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: _backgroundType == QuranVideoBackgroundType.image
            ? FileType.image
            : FileType.video,
        allowMultiple: false,
        withData: false,
      );
      if (result == null || result.files.isEmpty) return;
      final path = result.files.single.path;
      if (path == null || !await File(path).exists()) {
        _showMessage(
          'تعذر الوصول إلى الملف المختار. اختر ملفًا محفوظًا على الجهاز.',
        );
        return;
      }
      if (!mounted) return;
      final selectedType = _backgroundType;
      final previewRequest = ++_backgroundPreviewRequest;
      setState(() {
        _backgroundPath = path;
        _videoPreviewPath = null;
        _isPreparingBackgroundPreview =
            selectedType == QuranVideoBackgroundType.video;
        _result = null;
      });
      if (selectedType == QuranVideoBackgroundType.video) {
        try {
          final thumbnailPath = await _backgroundPreviewService
              .createVideoThumbnail(path);
          if (!mounted || previewRequest != _backgroundPreviewRequest) return;
          setState(() {
            _videoPreviewPath = thumbnailPath;
            _isPreparingBackgroundPreview = false;
          });
        } catch (_) {
          if (!mounted || previewRequest != _backgroundPreviewRequest) return;
          setState(() {
            _backgroundPath = null;
            _videoPreviewPath = null;
            _isPreparingBackgroundPreview = false;
          });
          _showMessage(
            'تعذر تجهيز معاينة لهذا المقطع. اختر فيديو آخر قبل التصدير.',
          );
        }
      }
    } catch (_) {
      _showMessage(
        'لم أتمكن من فتح ملف الخلفية. حاول اختيار صورة أو فيديو آخر.',
      );
    }
  }

  Future<void> _startExport() async {
    final fromVerse = _fromVerse;
    final toVerse = _toVerse;
    if (_backgroundPath == null) {
      _showMessage('اختر صورة أو فيديو للخلفية أولًا.');
      return;
    }
    if (_isPreparingBackgroundPreview ||
        (_backgroundType == QuranVideoBackgroundType.video &&
            _videoPreviewPath == null)) {
      _showMessage('انتظر ظهور معاينة الخلفية قبل تصدير الفيديو.');
      return;
    }
    if (fromVerse < 1 || toVerse < fromVerse || toVerse > _verseCount) {
      _showMessage('أدخل نطاق آيات صحيحًا من 1 إلى $_verseCount.');
      return;
    }
    if (_options.displayMode != QuranVideoDisplayMode.ayahByAyah &&
        !_reciter.supportsWordByWord) {
      _showMessage('التظليل كلمة بكلمة غير متاح لهذا القارئ.');
      return;
    }
    setState(() {
      _isExporting = true;
      _progress = const QuranVideoExportProgress(
        fraction: 0.02,
        message: 'جارٍ بدء التصدير…',
      );
      _result = null;
    });
    try {
      final result = await _exportService.export(
        reciter: _reciter,
        surahNumber: _surahNumber,
        fromVerse: fromVerse,
        toVerse: toVerse,
        backgroundPath: _backgroundPath!,
        backgroundType: _backgroundType,
        options: _options,
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress);
        },
      );
      if (!mounted) return;
      setState(() => _result = result);
      _showMessage('اكتمل إنشاء الفيديو. يمكنك حفظه أو مشاركته.');
    } on QuranVideoExportException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) _showMessage('حدث خطأ أثناء التصدير. حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _cancelExport() async {
    await _exportService.cancel();
    if (mounted) _showMessage('جارٍ إيقاف التصدير…');
  }

  Future<void> _saveToGallery() async {
    final result = _result;
    if (result == null) return;
    setState(() => _isSaving = true);
    try {
      var hasAccess = await Gal.hasAccess(toAlbum: true);
      if (!hasAccess) hasAccess = await Gal.requestAccess(toAlbum: true);
      if (!hasAccess) {
        _showMessage(
          'لم تُمنح صلاحية حفظ الفيديو في المعرض. يمكنك مشاركته بدلًا من ذلك.',
        );
        return;
      }
      await Gal.putVideo(result.path, album: 'عباد الرحمن');
      _showMessage('تم حفظ الفيديو في المعرض.');
    } catch (_) {
      _showMessage(
        'تعذر حفظ الفيديو في المعرض؛ جرّب مشاركته أو تحقق من الإذن.',
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _shareVideo() async {
    final result = _result;
    if (result == null) return;
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(result.path)],
          text: 'فيديو تلاوة قرآنية من تطبيق عباد الرحمن',
        ),
      );
    } catch (_) {
      _showMessage('تعذرت مشاركة الفيديو.');
    }
  }

  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
