import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/helpers/alert_helper.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/app_navigator.dart';
import 'package:ibad_al_rahmann/core/theme/app_colors.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/quran/quran_cubit.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/verse_player/verse_player_cubit.dart';
import 'package:ibad_al_rahmann/features/quran/data/models/selected_verse_model.dart';
import 'package:ibad_al_rahmann/features/quran/data/services/bookmark_service.dart';
import 'package:ibad_al_rahmann/features/quran/ui/widgets/bookmark_widget/bookmarks_dialog_header.dart';
import 'package:ibad_al_rahmann/features/quran/ui/widgets/bookmark_widget/bookmarks_empty_state.dart';
import 'package:ibad_al_rahmann/features/quran/ui/widgets/bookmark_widget/bookmarks_list.dart';
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
          return verse.verse.toLowerCase().contains(query) ||
              verse.verseReference.toLowerCase().contains(query) ||
              verse.surahNumber.toString().contains(query) ||
              verse.verseNumber.toString().contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(
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
                  : BookmarksList(
                      bookmarks: filteredBookmarks,
                      onNavigateToVerse: _navigateToVerse,
                      onPlayVerse: _playVerse,
                      onRemoveBookmark: _removeBookmark,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _removeBookmark(VerseModel verse) {
    BookmarkService.removeBookmark(verse);
    _loadBookmarks();
    AlertHelper.showWarningAlert(context, message: 'تم حذف الآية من المحفوظات');
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
