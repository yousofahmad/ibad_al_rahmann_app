import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:quran/quran.dart';

import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/app_navigator.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/int_extensions.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/theme.dart';
import 'package:ibad_al_rahmann/core/helpers/tafsir_helper.dart';
import 'package:ibad_al_rahmann/core/theme/app_styles.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/quran/quran_cubit.dart';
import 'package:ibad_al_rahmann/features/quran/data/models/selected_verse_model.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/verse_player/verse_player_cubit.dart';
import 'tafsir_language_selector.dart';

class VerseDetailsBottomSheet extends StatefulWidget {
  const VerseDetailsBottomSheet({
    super.key,
    required this.currentVerse,
    this.isDarkOverride,
  });

  final VerseModel currentVerse;
  final bool? isDarkOverride;

  @override
  State<VerseDetailsBottomSheet> createState() =>
      _VerseDetailsBottomSheetState();
}

class _VerseDetailsBottomSheetState extends State<VerseDetailsBottomSheet> {
  int _lastLoadedSurah = 0;
  late String _selectedBookId;
  final Map<String, bool> _downloadedStatus = {};
  final Map<String, double> _downloadProgress = {};
  final Map<String, bool> _isDownloading = {};
  bool _isLoadingTafsir = false;
  int _tafsirLoadGeneration = 0;

  VerseModel get _activeVerse =>
      context.read<VersePlayerCubit>().state.currentVerse ??
      widget.currentVerse;

  @override
  void initState() {
    super.initState();
    _selectedBookId = TafsirHelper.getSelectedBookId();
    _lastLoadedSurah = widget.currentVerse.surahNumber;
    _loadTafsirForSelected(widget.currentVerse);
    _checkAllDownloads();
  }

  Future<void> _checkAllDownloads() async {
    await TafsirHelper.fetchRemoteBooks();
    if (!mounted) return;
    final books = List<TafsirBook>.from(TafsirHelper.availableBooks);
    final statuses = <String, bool>{};
    for (final book in books) {
      statuses[book.id] = await TafsirHelper.isBookDownloaded(book.id);
    }
    if (!mounted) return;
    setState(() {
      _downloadedStatus.addAll(statuses);
      if (!books.any((book) => book.id == _selectedBookId)) {
        // An offline catalog miss must not erase the saved preference.
        _selectedBookId = 'muyassar';
      }
    });
    await _loadTafsirForSelected(_activeVerse);
  }

  Future<void> _loadTafsirForSelected(VerseModel verse) async {
    if (!mounted) return;
    final generation = ++_tafsirLoadGeneration;
    final bookId = _selectedBookId;
    setState(() => _isLoadingTafsir = true);
    final isDownloaded = await TafsirHelper.isBookDownloaded(bookId);
    if (isDownloaded || bookId == 'muyassar') {
      await TafsirHelper.loadSurahTafsir(bookId, verse.surahNumber);
    }
    if (mounted &&
        generation == _tafsirLoadGeneration &&
        bookId == _selectedBookId) {
      setState(() {
        _downloadedStatus[bookId] = isDownloaded;
        _isLoadingTafsir = false;
      });
    }
  }

  Future<void> _handleGroupSelection(TafsirBookGroup group) =>
      _handleBookSelection(TafsirHelper.preferredBookForGroup(group));

  Future<void> _handleBookSelection(TafsirBook book) async {
    setState(() {
      _selectedBookId = book.id;
    });
    await TafsirHelper.setSelectedBookId(book.id);
    if (!mounted || _selectedBookId != book.id) return;
    await _loadTafsirForSelected(_activeVerse);
  }

  Future<void> _startDownload(TafsirBook book) async {
    if (_isDownloading[book.id] == true) return;
    setState(() {
      _isDownloading[book.id] = true;
      _downloadProgress[book.id] = 0.0;
    });

    await TafsirHelper.downloadBook(
      book,
      onProgress: (p) {
        if (mounted) {
          setState(() {
            _downloadProgress[book.id] = p;
          });
        }
      },
      onComplete: (success, error) async {
        if (mounted) {
          setState(() {
            _isDownloading[book.id] = false;
            if (success) {
              _downloadedStatus[book.id] = true;
            }
          });
          if (mounted) {
            if (success) {
              await _loadTafsirForSelected(_activeVerse);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'تم تحميل ${book.name} (${book.languageLabel}) بنجاح!',
                    style: const TextStyle(fontFamily: AppConsts.expoArabic),
                  ),
                  backgroundColor: const Color(0xFF00897B),
                  duration: const Duration(seconds: 2),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'فشل تحميل التفسير: ${error ?? "خطأ غير معروف"}',
                    style: const TextStyle(fontFamily: AppConsts.expoArabic),
                  ),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      },
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeVerse =
        context.watch<VersePlayerCubit>().state.currentVerse ??
        widget.currentVerse;
    if (_lastLoadedSurah != activeVerse.surahNumber) {
      _lastLoadedSurah = activeVerse.surahNumber;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadTafsirForSelected(_activeVerse);
      });
    }
    final translation = getVerseTranslation(
      activeVerse.surahNumber,
      activeVerse.verseNumber,
    );

    final paperColor =
        (context.findAncestorWidgetOfExactType<BlocProvider>() != null
            ? context.read<QuranCubit>().state.quranPaperColor
            : null) ??
        (widget.isDarkOverride == true ? Colors.black : Colors.white);

    final bool isPaperDark = paperColor.computeLuminance() < 0.5;
    final Color sheetBg = isPaperDark ? const Color(0xFF000000) : Colors.white;
    final Color headerBg = Theme.of(context).primaryColor;
    final Color onSurface = isPaperDark ? Colors.white : Colors.black87;
    const goldColor = Color(0xFFD0A871);

    final books = TafsirHelper.availableBooks;
    final currentBook = books.firstWhere(
      (b) => b.id == _selectedBookId,
      orElse: () => TafsirHelper.defaultBooks.first,
    );
    final groups = TafsirHelper.availableBookGroups;
    final currentGroup = groups.firstWhere(
      (group) => group.id == currentBook.familyId,
    );
    final bool isCurrentDownloaded =
        _downloadedStatus[currentBook.id] ?? currentBook.isBuiltIn;
    final bool isDownloadingCurrent = _isDownloading[currentBook.id] == true;
    final double downloadProgressCurrent =
        _downloadProgress[currentBook.id] ?? 0.0;

    final tafsirText = isCurrentDownloaded
        ? TafsirHelper.getVerseTafsir(
            activeVerse.surahNumber,
            activeVerse.verseNumber,
            bookId: _selectedBookId,
          )
        : '';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(8),
              alignment: Alignment.center,
              width: double.infinity,
              decoration: BoxDecoration(
                color: headerBg,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                border: Border(
                  bottom: BorderSide(
                    color: !isPaperDark
                        ? Colors.grey.withAlpha(50)
                        : Colors.white10,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 40),
                  Text(
                    'سورة ${getSurahNameArabic(activeVerse.surahNumber)}, الآية: ${activeVerse.verseNumber.toArabicNums}',
                    style: context.headlineLarge.copyWith(color: Colors.white),
                  ),
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: Icon(
                      Icons.close_rounded,
                      size: 20.sp,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  // Verse Text
                  Text(
                    activeVerse.verse,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: context.headlineMedium.copyWith(
                      fontFamily: activeVerse.fontFamily,
                      fontSize: 27.sp,
                      height: 1.2,
                      color: onSurface,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Divider(color: onSurface.withAlpha(30)),
                  const SizedBox(height: 10),

                  // Tafseer Header & Selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'التفسير:',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontFamily: AppConsts.expoArabic,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: goldColor,
                        ),
                      ),
                      if (isCurrentDownloaded && tafsirText.isNotEmpty)
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: tafsirText));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('✅ تم نسخ نص التفسير'),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(8.r),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10.w,
                              vertical: 4.h,
                            ),
                            decoration: BoxDecoration(
                              color: goldColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8.r),
                              border: Border.all(
                                color: goldColor.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.copy_rounded,
                                  size: 14.sp,
                                  color: goldColor,
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  'نسخ التفسير',
                                  style: TextStyle(
                                    fontFamily: AppConsts.cairo,
                                    fontSize: 12.sp,
                                    color: goldColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 8.h),

                  // One chip per tafsir family, never one per language.
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true, // RTL order
                    child: Row(
                      children: groups.map((group) {
                        final isSelected = group.id == currentGroup.id;
                        final isDownloaded = group.variants.any(
                          (book) =>
                              _downloadedStatus[book.id] ?? book.isBuiltIn,
                        );
                        final isDown = group.variants.any(
                          (book) => _isDownloading[book.id] == true,
                        );

                        return Padding(
                          padding: EdgeInsets.only(left: 8.w),
                          child: InkWell(
                            onTap: () => _handleGroupSelection(group),
                            borderRadius: BorderRadius.circular(12.r),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: EdgeInsets.symmetric(
                                horizontal: 12.w,
                                vertical: 8.h,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? goldColor.withValues(alpha: 0.15)
                                    : (isPaperDark
                                          ? Colors.white10
                                          : Colors.grey.withValues(
                                              alpha: 0.08,
                                            )),
                                borderRadius: BorderRadius.circular(12.r),
                                border: Border.all(
                                  color: isSelected
                                      ? goldColor
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isDown) ...[
                                    SizedBox(
                                      width: 14.w,
                                      height: 14.w,
                                      child: const CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(
                                          goldColor,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 6.w),
                                  ] else if (!isDownloaded) ...[
                                    Icon(
                                      Icons.cloud_download_outlined,
                                      size: 15.sp,
                                      color: isSelected
                                          ? goldColor
                                          : Colors.grey,
                                    ),
                                    SizedBox(width: 4.w),
                                  ],
                                  Text(
                                    group.name,
                                    style: TextStyle(
                                      fontFamily: AppConsts.expoArabic,
                                      fontSize: 12.sp,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isSelected
                                          ? goldColor
                                          : onSurface.withValues(alpha: 0.75),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  SizedBox(height: 14.h),
                  TafsirLanguageSelector(
                    group: currentGroup,
                    selectedBookId: currentBook.id,
                    downloadedStatus: _downloadedStatus,
                    onChanged: _handleBookSelection,
                  ),
                  SizedBox(height: 14.h),

                  // Tafseer Content or Download Card
                  if (isCurrentDownloaded) ...[
                    if (_isLoadingTafsir) ...[
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: CircularProgressIndicator(color: goldColor),
                        ),
                      ),
                    ] else ...[
                      SelectableText(
                        tafsirText.isNotEmpty
                            ? tafsirText
                            : 'لا يتوفر نص تفسير لهذه الآية.',
                        textAlign: currentBook.isRtl
                            ? TextAlign.right
                            : TextAlign.left,
                        textDirection: currentBook.isRtl
                            ? TextDirection.rtl
                            : TextDirection.ltr,
                        style: TextStyle(
                          fontFamily: AppConsts.cairo,
                          fontSize: 14.5.sp,
                          height: 1.6,
                          color: onSurface,
                        ),
                      ),
                    ],
                  ] else ...[
                    // Download Prompt Card
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: isPaperDark
                            ? const Color(0xFF1E1E1E)
                            : const Color(0xFFF9F9F9),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: goldColor.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.menu_book_rounded,
                            size: 36.sp,
                            color: goldColor,
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            currentBook.name,
                            style: TextStyle(
                              fontFamily: AppConsts.expoArabic,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                              color: goldColor,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            currentBook.author,
                            style: TextStyle(
                              fontFamily: AppConsts.cairo,
                              fontSize: 11.5.sp,
                              color: onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          if (currentBook.size != null) ...[
                            SizedBox(height: 6.h),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10.w,
                                vertical: 3.h,
                              ),
                              decoration: BoxDecoration(
                                color: goldColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: Text(
                                'الحجم: ${currentBook.size} • يعمل بدون إنترنت بعد التحميل',
                                style: TextStyle(
                                  fontFamily: AppConsts.cairo,
                                  fontSize: 10.5.sp,
                                  color: goldColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                          SizedBox(height: 14.h),
                          if (isDownloadingCurrent) ...[
                            Column(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6.r),
                                  child: LinearProgressIndicator(
                                    value: downloadProgressCurrent > 0
                                        ? downloadProgressCurrent
                                        : null,
                                    minHeight: 8.h,
                                    backgroundColor: goldColor.withValues(
                                      alpha: 0.15,
                                    ),
                                    valueColor: const AlwaysStoppedAnimation(
                                      goldColor,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 6.h),
                                Text(
                                  'جاري التحميل: ${(downloadProgressCurrent * 100).toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    fontFamily: AppConsts.cairo,
                                    fontSize: 11.sp,
                                    color: goldColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            SizedBox(
                              width: double.infinity,
                              height: 42.h,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: goldColor,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: () => _startDownload(currentBook),
                                icon: const Icon(
                                  Icons.download_rounded,
                                  size: 20,
                                ),
                                label: Text(
                                  'تحميل ${currentBook.languageLabel}',
                                  style: TextStyle(
                                    fontFamily: AppConsts.expoArabic,
                                    fontSize: 13.5.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  if (currentBook.id == 'muyassar') ...[
                    SizedBox(height: 24.h),
                    Divider(color: onSurface.withAlpha(30)),
                    SizedBox(height: 12.h),

                    // Translation Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'الترجمة:',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontFamily: AppConsts.expoArabic,
                            fontSize: 15.sp,
                            fontWeight: FontWeight.bold,
                            color: goldColor,
                          ),
                        ),
                        Text(
                          'Translation:',
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.left,
                          style: AppStyles.style18e.copyWith(
                            color: onSurface.withAlpha(180),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    SelectableText(
                      translation,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.left,
                      style: AppStyles.style18e.copyWith(
                        color: onSurface.withAlpha(180),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 60.h),
          ],
        ),
      ),
    );
  }
}
