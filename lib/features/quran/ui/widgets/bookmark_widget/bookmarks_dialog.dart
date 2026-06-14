import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/helpers/alert_helper.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/app_navigator.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/quran/quran_cubit.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/verse_player/verse_player_cubit.dart';
import 'package:ibad_al_rahmann/features/quran/data/models/selected_verse_model.dart';
import 'package:ibad_al_rahmann/features/quran/data/services/bookmark_service.dart';
import 'package:ibad_al_rahmann/features/quran/ui/widgets/bookmark_widget/bookmarks_dialog_header.dart';
import 'package:ibad_al_rahmann/features/quran/ui/widgets/bookmark_widget/bookmarks_empty_state.dart';
import 'package:ibad_al_rahmann/features/quran/ui/widgets/bookmark_widget/bookmark_item.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class BookmarksDialog extends StatefulWidget {
  const BookmarksDialog({super.key});

  @override
  State<BookmarksDialog> createState() => _BookmarksDialogState();
}

class _BookmarksDialogState extends State<BookmarksDialog> {
  List<VerseModel> bookmarks = [];
  List<VerseModel> filteredBookmarks = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
    _searchController.addListener(_filterBookmarks);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadBookmarks() {
    setState(() {
      bookmarks = BookmarkService.getBookmarksSortedByDate();
      filteredBookmarks = bookmarks;
    });
  }

  void _filterBookmarks() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        filteredBookmarks = bookmarks;
      } else {
        filteredBookmarks = bookmarks.where((verse) {
          final labelMatch =
              verse.label?.toLowerCase().contains(query) ?? false;
          return labelMatch ||
              verse.verse.toLowerCase().contains(query) ||
              verse.verseReference.toLowerCase().contains(query) ||
              verse.surahNumber.toString().contains(query) ||
              verse.verseNumber.toString().contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final quranState = context.read<QuranCubit>().state;
    final paperColor = quranState.isWirdMode
        ? quranState.wirdPaperColor
        : quranState.quranPaperColor;
    
    // Body background follows the Mushaf paper's brightness
    final bool isPaperDark = (paperColor ?? Colors.white).computeLuminance() < 0.5;
    
    final dialogBg = isPaperDark ? const Color(0xFF000000) : Colors.white;

    return Dialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: isPaperDark ? Colors.white10 : Colors.transparent,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: SizedBox(
        height: 600,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BookmarksDialogHeader(
              bookmarkCount: bookmarks.length,
              onClose: () => Navigator.pop(context),
            ),
            SizedBox(height: 16.h),
            Expanded(
              child: filteredBookmarks.isEmpty
                  ? const BookmarksEmptyState()
                  : ListView.builder(
                      itemCount: filteredBookmarks.length,
                      itemBuilder: (context, index) {
                        final bookmark = filteredBookmarks[index];

                        return Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 8.h,
                          ),
                          child: BookmarkItem(
                            verse: bookmark,
                            onTap: () => _navigateToVerse(bookmark),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.play_arrow_rounded,
                                    color: !isPaperDark
                                        ? Colors.black
                                        : Colors.white,
                                  ),
                                  tooltip: 'تشغيل الآية',
                                  onPressed: () => _playVerse(bookmark),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.redAccent,
                                  ),
                                  tooltip: 'حذف',
                                  onPressed: () => showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('تأكيد الحذف'),
                                      content: const Text(
                                        'هل أنت متأكد من حذف هذه الآية المحفوظة؟',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text('إلغاء'),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                            _removeBookmark(bookmark);
                                          },
                                          child: const Text(
                                            'حذف',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _removeBookmark(VerseModel verse) {
    setState(() {
      BookmarkService.removeBookmark(verse);
      _loadBookmarks(); // Reload and filter the list
    });
  }

  void _playVerse(VerseModel verse) {
    final cubit = context.read<VersePlayerCubit>();
    cubit.setVerse(
      surahNumber: verse.surahNumber,
      verseNumber: verse.verseNumber,
      fontFamily: verse.fontFamily,
      verse: verse.verse,
    );
    cubit.show();
    cubit.initVerse();
    Navigator.pop(context);
  }

  void _navigateToVerse(VerseModel verse) async {
    try {
      context.pop();
      await context.read<QuranCubit>().navigateToVerse(
        surahNumber: verse.surahNumber,
        verseNumber: verse.verseNumber,
      );
    } catch (e) {
      if (mounted) {
        AlertHelper.showWarningAlert(context, message: 'حدث خطأ ما');
      }
    }
  }
}
