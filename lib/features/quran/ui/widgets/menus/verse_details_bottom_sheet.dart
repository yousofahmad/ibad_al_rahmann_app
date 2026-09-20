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

class VerseDetailsBottomSheet extends StatefulWidget {
  const VerseDetailsBottomSheet({
    super.key,
    required this.currentVerse,
    this.isDarkOverride,
  });

  final VerseModel currentVerse;
  final bool? isDarkOverride;

  @override
  State<VerseDetailsBottomSheet> createState() => _VerseDetailsBottomSheetState();
}

class _VerseDetailsBottomSheetState extends State<VerseDetailsBottomSheet> {
  int _lastLoadedSurah = 0;
  late String _selectedBookId;
  final Map<String, bool> _downloadedStatus = {};
  final Map<String, double> _downloadProgress = {};
  final Map<String, bool> _isDownloading = {};
  bool _isLoadingTafsir = false;

  @override
  void initState() {
    super.initState();
    _selectedBookId = TafsirHelper.getSelectedBookId();
    _checkAllDownloads();
  }

  Future<void> _checkAllDownloads() async {
    await TafsirHelper.fetchRemoteBooks();
    final books = TafsirHelper.availableBooks;
    for (var b in books) {
      final downloaded = await TafsirHelper.isBookDownloaded(b.id);
      if (mounted) {
        setState(() {
          _downloadedStatus[b.id] = downloaded;
        });
      }
    }
    await _loadTafsirForSelected(widget.currentVerse);
  }

  Future<void> _loadTafsirForSelected(VerseModel verse) async {
    setState(() => _isLoadingTafsir = true);
    final isDownloaded = await TafsirHelper.isBookDownloaded(_selectedBookId);
    if (isDownloaded || _selectedBookId == 'muyassar') {
      await TafsirHelper.loadSurahTafsir(
        _selectedBookId,
        verse.surahNumber,
      );
    }
    if (mounted) {
      setState(() {
        _downloadedStatus[_selectedBookId] = isDownloaded;
        _isLoadingTafsir = false;
      });
    }
  }

  Future<void> _handleBookSelection(TafsirBook book) async {
    setState(() {
      _selectedBookId = book.id;
    });
    await TafsirHelper.setSelectedBookId(book.id);
    await _loadTafsirForSelected(widget.currentVerse);
  }

  Future<void> _startDownload(TafsirBook book) async {
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
              await _loadTafsirForSelected(widget.currentVerse);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'تم تحميل ${book.name} بنجاح!',
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
    // Stop the audio player when the bottom sheet is closed
    if (mounted) {
      context.read<VersePlayerCubit>().hide();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeVerse = context.watch<VersePlayerCubit>().state.currentVerse ?? widget.currentVerse;
    if (_lastLoadedSurah != activeVerse.surahNumber) {
      _lastLoadedSurah = activeVerse.surahNumber;
      _loadTafsirForSelected(activeVerse);
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
    final bool isCurrentDownloaded = _downloadedStatus[currentBook.id] ?? currentBook.isBuiltIn;
    final bool isDownloadingCurrent = _isDownloading[currentBook.id] == true;
    final double downloadProgressCurrent = _downloadProgress[currentBook.id] ?? 0.0;

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
                    color: !isPaperDark ? Colors.grey.withAlpha(50) : Colors.white10,
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
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: goldColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8.r),
                              border: Border.all(color: goldColor.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.copy_rounded, size: 14.sp, color: goldColor),
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

                  // Tafseer Books Choice Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true, // RTL order
                    child: Row(
                      children: books.map((book) {
                        final isSelected = book.id == _selectedBookId;
                        final isDownloaded = _downloadedStatus[book.id] ?? book.isBuiltIn;
                        final isDown = _isDownloading[book.id] == true;

                        return Padding(
                          padding: EdgeInsets.only(left: 8.w),
                          child: InkWell(
                            onTap: () => _handleBookSelection(book),
                            borderRadius: BorderRadius.circular(12.r),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? goldColor.withValues(alpha: 0.15)
                                    : (isPaperDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.08)),
                                borderRadius: BorderRadius.circular(12.r),
                                border: Border.all(
                                  color: isSelected ? goldColor : Colors.transparent,
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
                                        valueColor: AlwaysStoppedAnimation(goldColor),
                                      ),
                                    ),
                                    SizedBox(width: 6.w),
                                  ] else if (!isDownloaded) ...[
                                    Icon(
                                      Icons.cloud_download_outlined,
                                      size: 15.sp,
                                      color: isSelected ? goldColor : Colors.grey,
                                    ),
                                    SizedBox(width: 4.w),
                                  ],
                                  Text(
                                    book.name,
                                    style: TextStyle(
                                      fontFamily: AppConsts.expoArabic,
                                      fontSize: 12.sp,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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

                  // Tafseer Content or Download Card
                  if (isCurrentDownloaded) ...[
                    if (_isLoadingTafsir) ...[
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: CircularProgressIndicator(color: goldColor),
                        ),
                      )
                    ] else ...[
                      SelectableText(
                        tafsirText.isNotEmpty ? tafsirText : 'لا يتوفر نص تفسير لهذه الآية.',
                        textAlign: TextAlign.right,
                        textDirection: TextDirection.rtl,
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
                        color: isPaperDark ? const Color(0xFF1E1E1E) : const Color(0xFFF9F9F9),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: goldColor.withValues(alpha: 0.25)),
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
                              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
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
                                    value: downloadProgressCurrent > 0 ? downloadProgressCurrent : null,
                                    minHeight: 8.h,
                                    backgroundColor: goldColor.withValues(alpha: 0.15),
                                    valueColor: const AlwaysStoppedAnimation(goldColor),
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
                                icon: const Icon(Icons.download_rounded, size: 20),
                                label: Text(
                                  'تحميل ${currentBook.name}',
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

